library ieee;
use ieee.std_logic_1164.all;

library paco_lut;
use paco_lut.lut_package.all;

entity lut_controller is
  port (
    clk : in std_logic;
    id_rst_i : in std_logic;
    id_stat_i : in std_logic;
    id_exe_i : in std_logic;
    id_cfg_i : in std_logic;
    data_i : in std_logic_vector(C_WORD_SIZE-1 downto 0);

    status_o : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    error_o : out std_logic;
    
    cfg_mode_o : out std_logic;
    cfg_o : out cfg_word_t;

    lut_addr_o : out std_logic_vector(C_SEGMENT_BITS-1 downto 0);
    lut_data_o : out std_logic_vector(C_LUT_BRAM_WIDTH-1 downto 0);
    lut_we_o   : out std_logic;

    pipeline_o : out p_input_t

  );
end entity;

architecture implementation of lut_controller is
begin 
  
  status_o <= (others => '0');
  error_o <= '0';

  cfg_mode_o <= '0';
  cfg_o.d <= (others => '0');

  lut_addr_o <= (others => '0');
  lut_data_o <= (others => '0');
  lut_we_o   <= '0';

  pipeline_o.data <= (others => '0');
  pipeline_o.valid <= '0';


end architecture;

