library ieee;
use ieee.std_logic_1164.all;

library paco_lut;
use paco_lut.lut_package.all;

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
begin
  cfg_o <= cfg_i;
  
  pipeline_o.valid <= '0';
  pipeline_o.selector <= (others => '0');
  pipeline_o.interpolator <= (others => '0');


end architecture;
