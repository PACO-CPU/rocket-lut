library ieee;
use ieee.std_logic_1164.all;

library paco_lut;
use paco_lut.lut_package.all;

entity bram_controller is
  port (
    clk : in std_logic;
    rst : in std_logic;
    
    cfg_i : in  cfg_word_t;
    cfg_o : out cfg_word_t;

    cfg_mode_i : in std_logic;
    ram_addr_i : in std_logic_vector(C_SEGMENT_BITS-1 downto 0);
    ram_data_i : in std_logic_vector(C_LUT_BRAM_WIDTH-1 downto 0);
    ram_we_i   : in std_logic;

    pipeline_i : in p_lut_t;
    pipeline_o : out p_interpolator_t

  );
end entity;

architecture implementation of bram_controller is
begin
  cfg_o <= cfg_i;
  
  pipeline_o.valid <= '0';
  pipeline_o.selector <= (others => '0');
  pipeline_o.interpolator <= (others => '0');
  pipeline_o.base <= (others => '0');
  pipeline_o.incline <= (others => '0');


end architecture;

