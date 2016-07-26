library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library work;
use work.lut_package.all;
use work.test_package.all;

entity tb_interpolator is
end entity;

architecture behavior of tb_interpolator is
  constant C_CLK_PERIOD : time := 10 ns;
  
  signal clk : std_logic;

  signal i_signals: inter_i_signals_t;
  signal o_signals: inter_o_signals_t;
   
  procedure init_signals(signal i: out inter_i_signals_t) is 
  begin
    i.id_rst_i <= '0';
    i.cfg_i.valid <= '0';
    i.cfg_i.d <= (others => '0');
    i.pipeline_i.valid <= '0';
    i.pipeline_i.interpolator <= (others => '0');
    i.pipeline_i.selector <= (others => '0');
    i.pipeline_i.base <= (others => '0');
    i.pipeline_i.incline <= (others => '0');
  end procedure;
  


  procedure set_data(
    signal i: out inter_i_signals_t; signal o: inter_o_signals_t;
    interpolator : integer; selector : integer; base : integer; incline : integer) is
  begin
    
    i.pipeline_i.valid <= '1'; 
    i.pipeline_i.interpolator <= conv_std_logic_vector(interpolator,C_INTERPOLATION_BITS);
    i.pipeline_i.selector <= conv_std_logic_vector(selector,C_SELECTOR_BITS);
    i.pipeline_i.base <= conv_std_logic_vector(base,C_BASE_BITS);
    i.pipeline_i.incline <= conv_std_logic_vector(incline,C_INCLINE_BITS);
    
  end procedure;
  
begin
  
  uut: interpolator port map (
    clk => clk,
    rst => i_signals.id_rst_i,

    cfg_i => i_signals.cfg_i,
    cfg_o => o_signals.cfg_o,

    pipeline_i => i_signals.pipeline_i,
    pipeline_o => o_signals.pipeline_o
  );

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

    set_data(i_signals,o_signals,12,0,100,5);

    wait;
  end process;
  
end;
