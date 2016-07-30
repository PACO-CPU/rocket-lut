
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

library paco_lut;
use paco_lut.lut_package.all;

package test_package is
  constant C_CLK_FREQ : integer := 100000000;
  constant C_BAUD_RATE : integer := 921600;

  constant CMD_ECHO : std_logic_vector(7 downto 0) := x"01";
  constant CMD_CFG_WORD : std_logic_vector(7 downto 0) := x"10";
  constant CMD_COMPUTE_PLA : std_logic_vector(7 downto 0) := x"21";
  constant CMD_COMPUTE_IDEC : std_logic_vector(7 downto 0) := x"22";
  constant CMD_COMPUTE_INTER : std_logic_vector(7 downto 0) := x"23";

  constant CMD_CORE_RST : std_logic_vector(7 downto 0) := x"30";
  constant CMD_CORE_STAT : std_logic_vector(7 downto 0) := x"31";
  constant CMD_CORE_EXE : std_logic_vector(7 downto 0) := x"32";
  constant CMD_CORE_CFG : std_logic_vector(7 downto 0) := x"33";
  constant CMD_CORE_EXE_BEGIN : std_logic_vector(7 downto 0) := x"34";

  constant CMD_DIAG_CLOCK_COUNTER : std_logic_vector(7 downto 0) := x"40";
  constant CMD_DIAG_OUTPUT_COUNTER : std_logic_vector(7 downto 0) := x"41";

  constant CMD_CFG_INPUT_WORDS : std_logic_vector(7 downto 0) := x"0b";
  constant CMD_CFG_SELECTOR_BITS : std_logic_vector(7 downto 0) := x"02";
  constant CMD_CFG_INTERPOLATION_BITS : std_logic_vector(7 downto 0) := x"03";
  constant CMD_CFG_SEGMENT_BITS : std_logic_vector(7 downto 0) := x"04";
  constant CMD_CFG_PLA_INTERCONNECTS : std_logic_vector(7 downto 0) := x"05";
  constant CMD_CFG_BASE_BITS : std_logic_vector(7 downto 0) := x"06";
  constant CMD_CFG_INCLINE_BITS : std_logic_vector(7 downto 0) := x"07";
  constant CMD_CFG_CONTROLLER_DELAY : std_logic_vector(7 downto 0) := x"0c";
  constant CMD_CFG_ADDRESS_TRANSLATOR_DELAY : std_logic_vector(7 downto 0) := x"08";
  constant CMD_CFG_INTERPOLATOR_DELAY : std_logic_vector(7 downto 0) := x"09";
  constant CMD_CFG_INPUT_DECODER_DELAY : std_logic_vector(7 downto 0) := x"0a";
  
  type idec_i_signals_t is record
    id_rst_i : std_logic;
    cfg_i : cfg_word_t;
    pipeline_i : p_input_t;
  end record;

  type idec_o_signals_t is record
    cfg_o : cfg_word_t;
    pipeline_o : p_pla_t;
  end record;
  type pla_i_signals_t is record
    id_rst_i : std_logic;
    cfg_i : cfg_word_t;
    pipeline_i : p_pla_t;
  end record;

  type pla_o_signals_t is record
    cfg_o : cfg_word_t;
    pipeline_o : p_lut_t;
  end record;

  type inter_i_signals_t is record
    id_rst_i : std_logic;
    cfg_i : cfg_word_t;
    pipeline_i : p_interpolator_t;
  end record;

  type inter_o_signals_t is record
    cfg_o : cfg_word_t;
    pipeline_o : p_output_t;
  end record;

  type core_i_signals_t is record
    id_rst_i : std_logic;
    id_stat_i : std_logic;
    id_exe_i : std_logic;
    id_cfg_i : std_logic;
    data_i : std_logic_vector(C_WORD_SIZE-1 downto 0);
    data2_i : std_logic_vector(C_WORD_SIZE-1 downto 0);
    data3_i : std_logic_vector(C_WORD_SIZE-1 downto 0);
  end record;

  type core_o_signals_t is record
    data_o : std_logic_vector(C_WORD_SIZE-1 downto 0);
    data_valid_o : std_logic;
    status_o : std_logic_vector(C_WORD_SIZE-1 downto 0);
    error_o : std_logic;
  end record;



  component uart_receiver
    generic(
      CLK_FREQ  : integer := 50000000;
      BAUD_RATE : integer := 9600
    );
    port(
      clk      : in  STD_LOGIC;
      rst      : in  STD_LOGIC;
      rxd      : in  STD_LOGIC;
      valid : out STD_LOGIC;
      do       : out STD_LOGIC_VECTOR (7 downto 0)
    );
  end component;


  component uart_transmitter
    generic(
      CLK_FREQ  : integer := 50000000;
      BAUD_RATE : integer := 9600
    );
    port(
      clk : in  STD_LOGIC;
      rst : in  STD_LOGIC;
      txd : out std_logic;
      di    : in  STD_LOGIC_VECTOR (7 downto 0);
      valid : in  STD_LOGIC;
      ready : out  STD_LOGIC
    );
  end component;

  procedure ht_common_cmd(
    signal rx_data : std_logic_vector;
    signal tx_valid : out std_logic;
    signal tx_data  : out std_logic_vector); 


end package;

package body test_package is

  procedure ht_common_cmd(
    signal rx_data : std_logic_vector;
    signal tx_valid : out std_logic;
    signal tx_data  : out std_logic_vector) is
  begin
    
    case rx_data is
      when CMD_CFG_INPUT_WORDS =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_INPUT_WORDS,8);
      when CMD_CFG_SELECTOR_BITS =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_SELECTOR_BITS,8);
      when CMD_CFG_INTERPOLATION_BITS =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_INTERPOLATION_BITS,8);
      when CMD_CFG_SEGMENT_BITS =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_SEGMENT_BITS,8);
      when CMD_CFG_PLA_INTERCONNECTS =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_PLA_INTERCONNECTS,8);
      when CMD_CFG_BASE_BITS =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_BASE_BITS,8);
      when CMD_CFG_INCLINE_BITS =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_INCLINE_BITS,8);
      when CMD_CFG_CONTROLLER_DELAY =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_CONTROLLER_DELAY,8);
      when CMD_CFG_INPUT_DECODER_DELAY =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_INPUT_DECODER_DELAY,8);
      when CMD_CFG_ADDRESS_TRANSLATOR_DELAY =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_ADDRESS_TRANSLATOR_DELAY,8);
      when CMD_CFG_INTERPOLATOR_DELAY =>
        tx_valid <= '1';
        tx_data <= conv_std_logic_vector(C_INTERPOLATOR_DELAY,8);
      when others =>
        tx_valid <= '1';
        tx_data <= rx_data;
    end case;
  end procedure;
end package body;

