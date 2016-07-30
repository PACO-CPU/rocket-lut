library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library paco_lut;
use paco_lut.lut_package.all;

--! @brief The final stage of the LUT HW core pipeline, performing a
--! multiply-and-add operation.
--! @details Performs the operation base + incline * (selector ~ interpolator),
--! adding base to the product of incline and the concatenation of the
--! selector bits and the interpolator bits. 
--! base and incline are interpreted as two's complement and the
--! selector/interpolator concatenation is unsigned.
--!
--! The MAD operation is done in combinational logic with a configurable
--! number (C_INTERPOLATOR_DELAY) of succeeding delay steps.
entity interpolator is
  port (
    clk : in std_logic;
    rst : in std_logic;
    
    cfg_i : in  cfg_word_t;
    cfg_o : out cfg_word_t;

    pipeline_i : in p_interpolator_t;
    pipeline_o : out p_output_t

  );
end entity;

architecture implementation of interpolator is
  constant C_RESULT_BITS : integer :=
    max(
      C_INCLINE_BITS+C_INTERPOLATION_BITS+C_SELECTOR_BITS+1,
      C_BASE_BITS+1);
  constant C_RESULT_BITS_EXT : integer := max(C_WORD_SIZE,C_RESULT_BITS);
  type p_delay_t is array(0 to C_INTERPOLATOR_DELAY) of p_output_t;
  signal p_delay : p_delay_t;
  signal p_result : p_output_t;
  signal result_bv : std_logic_vector(C_RESULT_BITS-1 downto 0);
  signal result_bv_ext : std_logic_vector(C_RESULT_BITS_EXT-1 downto 0);
begin
  cfg_o <= cfg_i; -- no configuration words
  
  -- raw result bits: base + incline*(selector & interpolator)
  result_bv <= 
    std_logic_vector(
      signed(pipeline_i.base)+
      signed(pipeline_i.incline)*signed("0"&pipeline_i.selector&pipeline_i.interpolator));
  -- sign-extended result vector
  result_bv_ext(C_RESULT_BITS_EXT-1 downto C_RESULT_BITS) <= 
    (others => result_bv(C_RESULT_BITS-1));
  result_bv_ext(C_RESULT_BITS-1 downto 0) <= result_bv;
  
  -- sign-aware extraction of the result's LSB
  p_result.valid <= pipeline_i.valid;
  p_result.data <= result_bv_ext(C_WORD_SIZE-1 downto 0);
 
  -- delay pipeline: result -> delay(0) -> ... -> pipeline_o
  -- since p_result and pipeline_o are combinational, even a setting of 
  -- C_INTERPOLATOR_DELAY=0 should work.
  p_delay(0) <= p_result;
  process (clk) is
    variable i: integer;
  begin
    if rising_edge(clk) then
      
      for i in 1 to C_INTERPOLATOR_DELAY loop
        p_delay(i) <= p_delay(i-1);
      end loop;
      
      if rst='1' then
        for i in 1 to C_INTERPOLATOR_DELAY loop
          p_delay(i).valid <= '0';
        end loop;
      end if;

    end if;
  end process;
  
  pipeline_o <= p_delay(C_INTERPOLATOR_DELAY);

end architecture;
