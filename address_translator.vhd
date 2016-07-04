library ieee;
use ieee.std_logic_1164.all;

library paco_lut;
use paco_lut.lut_package.all;


entity address_translator is
  port (
    clk : in std_logic;
    rst : in std_logic;
    
    cfg_i : in  cfg_word_t;
    cfg_o : out cfg_word_t;

    pipeline_i : in p_pla_t;
    pipeline_o : out p_lut_t

  );
end entity;

architecture implementation of address_translator is
  type and_crosspoints_t is 
    array(0 to C_PLA_INTERCONNECTS-1) of 
    std_logic_vector(
      C_CFG_WORD_SIZE*C_CFG_PLA_AND_REGISTERS_PER_ROW-1 downto 0);
    --2*C_SELECTOR_BITS-1);
  signal and_crosspoints : and_crosspoints_t;

  type or_crosspoints_t is
    array(0 to C_SEGMENT_BITS-1) of
    std_logic_vector(
      C_CFG_WORD_SIZE*C_CFG_PLA_OR_REGISTERS_PER_COLUMN-1 downto 0);
    --C_PLA_INTERCONNECTS-1);
  signal or_crosspoints : or_crosspoints_t;

  signal interconnects: std_logic_vector(C_PLA_INTERCONNECTS-1 downto 0);

  signal outputs : std_logic_vector(C_SEGMENT_BITS-1 downto 0);

  type p_delay_t is array(0 to C_INTERPOLATOR_DELAY) of p_lut_t;
  signal p_delay : p_delay_t;

  function reduce_and(s : std_logic_vector) return std_logic is
    variable v : std_logic;
    variable i: integer;
  begin
    v := '1';
    for i in s'range loop
      v := v and s(i);
    end loop;
    return v;
  end function;

  function reduce_or(s : std_logic_vector) return std_logic is
    variable v : std_logic;
    variable i: integer;
  begin
    v := '1';
    for i in s'range loop
      v := v or s(i);
    end loop;
    return v;
  end function;
  
  function compute_interconnects(
    input : std_logic_vector; 
    crosspoints : and_crosspoints_t) 
    return std_logic_vector is
    variable res : std_logic_vector(0 to C_PLA_INTERCONNECTS-1);
    variable i: integer;
  begin
    for i in 0 to C_PLA_INTERCONNECTS-1 loop
      res(i) := reduce_and(
        (input & not input) and crosspoints(i)(2*C_SELECTOR_BITS-1 downto 0));
    end loop;
    return res;
  end function;

  function compute_outputs(
    interconnects : std_logic_vector;
    crosspoints : or_crosspoints_t)
    return std_logic_vector is
    variable res : std_logic_vector(0 to C_SEGMENT_BITS-1);
    variable i: integer;
  begin
    for i in 0 to C_SEGMENT_BITS-1 loop
      res(i) := reduce_or(
        interconnects & crosspoints(i)(C_PLA_INTERCONNECTS-1 downto 0));
    end loop;
    return res;
  end function;
begin
  cfg_o.valid <= cfg_i.valid;
  
  -- PLA combinational logic
  interconnects <= compute_interconnects(
    pipeline_i.selector,
    and_crosspoints);

  outputs <= compute_outputs(
    interconnects,
    or_crosspoints);

  -- PLA result insertion into delay pipeline
  p_delay(0).valid <= pipeline_i.valid;
  p_delay(0).selector <= pipeline_i.selector;
  p_delay(0).interpolator <= pipeline_i.interpolator;
  p_delay(0).address <= outputs;
  
  -- configuration logic
  process (clk) is 
  begin
    
    if rising_edge(clk) and cfg_i.valid='1' then
      
      -- AND plane registers
      for i in 0 to C_PLA_INTERCONNECTS-1 loop
        if i=0 then
          and_crosspoints(i)(
            C_CFG_WORD_SIZE*(C_CFG_PLA_AND_REGISTERS_PER_ROW  )-1 downto 
            C_CFG_WORD_SIZE*(C_CFG_PLA_AND_REGISTERS_PER_ROW-1)) <=
            cfg_i.d;
        else
          and_crosspoints(i)(
            C_CFG_WORD_SIZE*(C_CFG_PLA_AND_REGISTERS_PER_ROW  )-1 downto 
            C_CFG_WORD_SIZE*(C_CFG_PLA_AND_REGISTERS_PER_ROW-1)) <=
            and_crosspoints(i-1)(C_CFG_WORD_SIZE-1 downto 0);
        end if;

        for j in 1 to C_CFG_PLA_AND_REGISTERS_PER_ROW-1 loop
          and_crosspoints(i)(
            C_CFG_WORD_SIZE*(C_CFG_PLA_AND_REGISTERS_PER_ROW-j  )-1 downto 
            C_CFG_WORD_SIZE*(C_CFG_PLA_AND_REGISTERS_PER_ROW-j-1)) <=
            and_crosspoints(i)(
              C_CFG_WORD_SIZE*(C_CFG_PLA_AND_REGISTERS_PER_ROW-j+1)-1 downto 
              C_CFG_WORD_SIZE*(C_CFG_PLA_AND_REGISTERS_PER_ROW-j  ));
        end loop;
      end loop;
      
      -- OR plane registers
      for i in 0 to C_SEGMENT_BITS-1 loop
        if i=0 then
          or_crosspoints(i)(
            C_CFG_WORD_SIZE*(C_CFG_PLA_OR_REGISTERS_PER_COLUMN  )-1 downto 
            C_CFG_WORD_SIZE*(C_CFG_PLA_OR_REGISTERS_PER_COLUMN-1)) <=
            and_crosspoints(C_PLA_INTERCONNECTS-1)(C_CFG_WORD_SIZE-1 downto 0);
        else
          or_crosspoints(i)(
            C_CFG_WORD_SIZE*(C_CFG_PLA_OR_REGISTERS_PER_COLUMN  )-1 downto 
            C_CFG_WORD_SIZE*(C_CFG_PLA_OR_REGISTERS_PER_COLUMN-1)) <=
            or_crosspoints(i-1)(C_CFG_WORD_SIZE-1 downto 0);
        end if;

        for j in 1 to C_CFG_PLA_OR_REGISTERS_PER_COLUMN-1 loop
          or_crosspoints(i)(
            C_CFG_WORD_SIZE*(C_CFG_PLA_OR_REGISTERS_PER_COLUMN-j  )-1 downto 
            C_CFG_WORD_SIZE*(C_CFG_PLA_OR_REGISTERS_PER_COLUMN-j-1)) <=
            or_crosspoints(i)(
              C_CFG_WORD_SIZE*(C_CFG_PLA_OR_REGISTERS_PER_COLUMN-j+1)-1 downto 
              C_CFG_WORD_SIZE*(C_CFG_PLA_OR_REGISTERS_PER_COLUMN-j  ));
        end loop;
      end loop;


    end if;
  end process;
  cfg_o.d <= or_crosspoints(C_SEGMENT_BITS-1)(C_CFG_WORD_SIZE-1 downto 0);
  
  -- delay pipeline sequential logic
  process (clk) is
    variable i: integer;
  begin
    if rising_edge(clk) then
      
      for i in 1 to C_ADDRESS_TRANSLATOR_DELAY loop
        p_delay(i) <= p_delay(i-1);
      end loop;
      
      if rst='1' then
        for i in 1 to C_INTERPOLATOR_DELAY loop
          p_delay(i).valid <= '0';
        end loop;
      end if;

    end if;
  end process;
  
  -- delay pipeline -> output
  pipeline_o <= p_delay(C_ADDRESS_TRANSLATOR_DELAY);


end architecture;
