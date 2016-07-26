library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lut_package.all;

entity tb_ is
end entity;

architecture behavior of tb_ is
  constant C_CLK_PERIOD : time := 10 ns;
  
  signal clk : std_logic;

  type i_signals_t is record
    id_rst_i : std_logic;
  end record;

  signal i_signals: i_signals_t;
  signal o_signals: o_signals_t;
   
  procedure init_signals(signal i: out i_signals_t) is 
  begin
    i.id_rst_i <= '0';
  end procedure;

begin
  clk_gen: process begin
    clk <= '1';
    wait for C_CLK_PERIOD/2;
    clk <= '0';
    wait for C_CLK_PERIOD/2;
  end process;
  
  stim: process begin
    init_signals(i_signals);
 
    i_signals.id_rst_i <= '1';
    wait for C_CLK_PERIOD*40;
    i_signals.id_rst_i <= '0';
    wait for C_CLK_PERIOD/2;

    wait;
  end process;
  
end;
