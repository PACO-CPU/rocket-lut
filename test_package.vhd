
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

library paco_lut;
use paco_lut.lut_package.all;

package test_package is
  constant CMD_ECHO : std_logic_vector(7 downto 0) := x"01";
  constant CMD_CFG_WORD : std_logic_vector(7 downto 0) := x"10";
  constant CMD_COMPUTE_PLA : std_logic_vector(7 downto 0) := x"21";

  constant CMD_CFG_SELECTOR_BITS : std_logic_vector(7 downto 0) := x"02";
  constant CMD_CFG_INTERPOLATION_BITS : std_logic_vector(7 downto 0) := x"03";
  constant CMD_CFG_SEGMENT_BITS : std_logic_vector(7 downto 0) := x"04";
  constant CMD_CFG_PLA_INTERCONNECTS : std_logic_vector(7 downto 0) := x"05";
  constant CMD_CFG_BASE_BITS : std_logic_vector(7 downto 0) := x"06";
  constant CMD_CFG_INCLINE_BITS : std_logic_vector(7 downto 0) := x"07";
  
  type pla_i_signals_t is record
    id_rst_i : std_logic;
    cfg_i : cfg_word_t;
    pipeline_i : p_pla_t;
  end record;

  type pla_o_signals_t is record
    cfg_o : cfg_word_t;
    pipeline_o : p_lut_t;
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


end package;

package body test_package is

end package body;

