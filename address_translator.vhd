
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lut_package.all;


--! @brief Address translator (PLA) pipeline stage for the LUT HW core
--! @details Performs an m:n bit translation implemented as a PLA. 
--! The input (pipeline_i.selector) is extended by concatenating it with its 
--! negative to form the extended input vector.
--! This is then and combined with a number of configurable vectors 
--! (AND-plane crosspoints) and AND-reduced to produce the interconnect 
--! vector.
--! This interconnect vector is then again and combined with a second set
--! of configurable vectors (OR-plane) crosspoints and AND-reduced to
--! produce the final output (pipeline_o.address) of this pipeline stage.
--!
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

--! The implemetation of the address translator PLA is done entirely in 
--! combinatorial logic, succeeded by a configurable 
--! (C_ADDRESS_TRANSLATOR_DELAY) number of register steps. This way
--! the LUT hardware core can be configured to work even when embedded in a
--! fast clock domain.
architecture implementation of address_translator is
  
  -- crosspoints for the AND plane. 
  type and_crosspoints_t is 
    array(0 to C_PLA_INTERCONNECTS-1) of 
    std_logic_vector(
      C_CFG_WORD_SIZE*C_CFG_PLA_AND_REGISTERS_PER_ROW-1 downto 0);
  signal and_crosspoints : and_crosspoints_t;
  
  -- crosspoints for the OR plane.
  type or_crosspoints_t is
    array(0 to C_SEGMENT_BITS-1) of
    std_logic_vector(
      C_CFG_WORD_SIZE*C_CFG_PLA_OR_REGISTERS_PER_COLUMN-1 downto 0);
  signal or_crosspoints : or_crosspoints_t;
  
  -- interconnect vector
  signal interconnects: std_logic_vector(C_PLA_INTERCONNECTS-1 downto 0);

  signal outputs : std_logic_vector(C_SEGMENT_BITS-1 downto 0);

  type p_delay_t is array(0 to C_ADDRESS_TRANSLATOR_DELAY) of p_lut_t;
  signal p_delay : p_delay_t;
  signal p_result : p_lut_t;

begin
  cfg_o.valid <= cfg_i.valid;

  -- PLA combinational logic
  process(clk) is 
    variable t_and_line : std_logic_vector(2*C_SELECTOR_BITS-1 downto 0);
    variable t_or_line : std_logic_vector(C_PLA_INTERCONNECTS-1 downto 0);
    variable t_interconnects : std_logic_vector(C_PLA_INTERCONNECTS-1 downto 0);
    constant AND_ONE : std_logic_vector(2*C_SELECTOR_BITS-1 downto 0) :=
      (others => '1');
    constant OR_ZERO : std_logic_vector(C_PLA_INTERCONNECTS-1 downto 0) :=
      (others => '0');
    variable i : integer;
  begin 
    -- valid, selector and interpolator are handed through to succeeding 
    -- pipeline stages as-is.
    p_result.valid <= pipeline_i.valid;
    p_result.selector <= pipeline_i.selector;
    p_result.interpolator <= pipeline_i.interpolator;

    -- compute the interconnects via the AND plane
    for i in 0 to C_PLA_INTERCONNECTS-1 loop
      -- AND combination of the extended input with a line from the AND 
      -- crosspoints
      t_and_line := 
        (
          (pipeline_i.selector & not pipeline_i.selector) and 
          and_crosspoints(i)(2*C_SELECTOR_BITS-1 downto 0)) or
        (not and_crosspoints(i)(2*C_SELECTOR_BITS-1 downto 0));

      -- AND-reduce: '1' iff all bits are one.
      if t_and_line=AND_ONE then
        t_interconnects(i) := '1';
      else 
        t_interconnects(i) := '0';
      end if;
    end loop;
    
    -- compute the outputs via the OR plane
    for i in 0 to C_SEGMENT_BITS-1 loop
      -- AND combination of the interconnects with a column from the OR
      -- crosspoints
      t_or_line := 
        t_interconnects and or_crosspoints(i)(C_PLA_INTERCONNECTS-1 downto 0);

      -- OR-reduce: '0' iff all bits are zero
      if t_or_line=OR_ZERO then
        p_result.address(i) <= '0';
      else
        p_result.address(i) <= '1';
      end if;
    end loop;
    
  end process;

  -- configuration logic
  process (clk) is 
    variable i: integer;
    variable j: integer;
    
    -- configuration is done by shifting a word of data through all 
    -- configuration words. Therefore the bit widths of each AND plane
    -- line and OR plane column are multiples of the configuration word
    -- size. 
    -- 
    -- The data from cfg_in is shifted in to the most significant word of the
    -- first line of the AND plane. 
    -- The shift moves on to the next less significant word of the same line
    -- until the least significant word is reached, after which input is 
    -- shifted into the most-significant word of the next line of the AND 
    -- plane and so on.
    -- The OR plane is fed in the same manner, the first input being the
    -- least significant word of the final AND plane line.
    
    --   msb          lsb
    --   +----+----+----+
    --   |   -->  -->  ---\   word 1 (first line of AND plane)
    --   +----+----+----+ |
    -- /------------------/
    -- | +----+----+----+
    -- \-->  -->  -->  ---\   word 2 (second line of AND plane)
    --   +----+----+----+ |
    -- /------------------/
    --        ...
    --        ...
    --        ...
    -- 
    -- | +----+----+----+
    -- \-->  -->  -->  ---\   word n (last line of AND plane)
    --   +----+----+----+ |
    -- /------------------/
    -- | +----+----+
    -- \-->  -->  ---\        word 1 (first column of OR plane)
    --   +----+----+ |
    -- /-------------/
    --      ....

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
  
  -- delay pipeline: result -> delay(0) -> ... -> pipeline_o
  -- since p_result and pipeline_o are combinational, even a setting of 
  -- C_ADDRESS_TRANSLATOR_DELAY=0 should work.
  p_delay(0) <= p_result;
  process (clk) is
    variable i: integer;
  begin
    if rising_edge(clk) then
      
      for i in 1 to C_ADDRESS_TRANSLATOR_DELAY loop
        p_delay(i) <= p_delay(i-1);
      end loop;
      
      if rst='1' then
        for i in 1 to C_ADDRESS_TRANSLATOR_DELAY loop
          p_delay(i).valid <= '0';
        end loop;
      end if;

    end if;
  end process;
  pipeline_o <= p_delay(C_ADDRESS_TRANSLATOR_DELAY);
  
end architecture;
