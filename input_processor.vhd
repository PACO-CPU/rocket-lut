library ieee;
use ieee.std_logic_1164.all;

library paco_lut;
use paco_lut.lut_package.all;

--! @brief Input bit selector pipeline stage for the LUT HW core
--! @details The first pipeline stage inputs an input bitvector comprised of
--! a number of input words coming from the processor pipeline. In this stage
--! the selector and interpolator bitvectors are selected from that input 
--! vector by means of an OR plane.
--! For each bit of the selector and interpolator, the input bitvector is
--! AND-combined with a configurable vector. The resulting bitvectors are then
--! OR-reduced to form the individual bits of the selector and interpolator.
--! In this core, the LSB of the interpolator is the first selected bit,
--! followed by the more significant bits of the interpolator and then the
--! LSB of the selector, followed by the more significant bits of the selector.
--! The configuration logic chains together the bitvectors of each bit in 
--! that order. To allow for all bits to be arranged in a shift register, the
--! bit vector widths are all a multiple of the configuration word size.
--! In each bitvector, the most significant word is always the first one in
--! the chain.
entity input_processor is
  port (
    clk : in std_logic;
    rst : in std_logic;
    
    cfg_i : in  cfg_word_t;
    cfg_o : out cfg_word_t;

    pipeline_i : in p_input_t;
    pipeline_o : out p_pla_t

  );
end entity;

architecture implementation of input_processor is
  type crosspoints_t is
    array(0 to C_SELECTOR_BITS+C_INTERPOLATION_BITS-1) of
    std_logic_vector(
      C_CFG_WORD_SIZE*C_CFG_INPUT_DECODER_REGISTERS_PER_BIT-1 downto 0);
  signal crosspoints : crosspoints_t;

  type p_delay_t is array(0 to C_INPUT_DECODER_DELAY) of p_pla_t;
  signal p_delay : p_delay_t;
  signal p_result : p_pla_t;
begin
  cfg_o.valid <= cfg_i.valid;
  
  -- input decoder combinational logic
  process(clk) is 
    variable or_line : std_logic_vector(C_INPUT_WORD_SIZE-1 downto 0);
    constant OR_ZERO : std_logic_vector(C_INPUT_WORD_SIZE-1 downto 0) :=
      (others => '0');
    variable i : integer;
    variable result_word : 
      std_logic_vector(C_SELECTOR_BITS+C_INTERPOLATION_BITS-1 downto 0);
  begin
    
    p_result.valid <= pipeline_i.valid;
    
    for i in 0 to C_SELECTOR_BITS+C_INTERPOLATION_BITS-1 loop
      -- AND combine the input with a column of crosspoints
      or_line := crosspoints(i) and pipeline_i.data;

      -- OR-combine the result to form a bit of the resulting 
      -- selector/interpolator
      if or_line=OR_ZERO then
        result_word(i) := '0';
      else
        result_word(i) := '1';
      end if;
    end loop;
    -- distribute the bits among the pipeline outputs
    p_result.selector <= result_word(
      C_SELECTOR_BITS+C_INTERPOLATION_BITS-1 downto C_INTERPOLATION_BITS);
    p_result.interpolator <= result_word(C_INTERPOLATION_BITS-1 downto 0);
   
  end process;
  

  -- configuration logic
  process (clk) is 
    variable i: integer;
    variable j: integer;
  begin 
    if rising_edge(clk) and cfg_i.valid='1' then
      -- AND plane registers
      for i in 0 to C_SELECTOR_BITS+C_INTERPOLATION_BITS-1 loop
        if i=0 then
          crosspoints(i)(
            C_CFG_WORD_SIZE*(C_CFG_INPUT_DECODER_REGISTERS_PER_BIT  )-1 downto 
            C_CFG_WORD_SIZE*(C_CFG_INPUT_DECODER_REGISTERS_PER_BIT-1)) <=
            cfg_i.d;
        else
          crosspoints(i)(
            C_CFG_WORD_SIZE*(C_CFG_INPUT_DECODER_REGISTERS_PER_BIT  )-1 downto 
            C_CFG_WORD_SIZE*(C_CFG_INPUT_DECODER_REGISTERS_PER_BIT-1)) <=
            crosspoints(i-1)(C_CFG_WORD_SIZE-1 downto 0);
        end if;

        for j in 1 to C_CFG_INPUT_DECODER_REGISTERS_PER_BIT-1 loop
          crosspoints(i)(
            C_CFG_WORD_SIZE*(C_CFG_INPUT_DECODER_REGISTERS_PER_BIT-j  )-1 downto 
            C_CFG_WORD_SIZE*(C_CFG_INPUT_DECODER_REGISTERS_PER_BIT-j-1)) <=
            crosspoints(i)(
              C_CFG_WORD_SIZE*(C_CFG_INPUT_DECODER_REGISTERS_PER_BIT-j+1)-1 downto 
              C_CFG_WORD_SIZE*(C_CFG_INPUT_DECODER_REGISTERS_PER_BIT-j  ));
        end loop;
      end loop;
      
      -- OR plane
    end if;
  end process;
  cfg_o.d <= 
    crosspoints(
      C_SELECTOR_BITS+C_INTERPOLATION_BITS-1)(C_CFG_WORD_SIZE-1 downto 0);

  -- delay pipeline: result -> delay(0) -> ... -> pipeline_o
  -- since p_result and pipeline_o are combinational, even a setting of 
  -- C_INPUT_DECODER_DELAY=0 should work.
  p_delay(0) <= p_result;
  process (clk) is
    variable i: integer;
  begin
    if rising_edge(clk) then
      
      for i in 1 to C_INPUT_DECODER_DELAY loop
        p_delay(i) <= p_delay(i-1);
      end loop;
      
      if rst='1' then
        for i in 1 to C_INPUT_DECODER_DELAY loop
          p_delay(i).valid <= '0';
        end loop;
      end if;

    end if;
  end process;
  pipeline_o <= p_delay(C_INPUT_DECODER_DELAY);

end architecture;
