library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library work;
use work.lut_package.all;
use work.test_package.all;

entity tb_input_processor is
end entity;

architecture behavior of tb_input_processor is
  constant C_CLK_PERIOD : time := 10 ns;
  
  signal clk : std_logic;

  signal i_signals: idec_i_signals_t;
  signal o_signals: idec_o_signals_t;
   
  procedure init_signals(signal i: out idec_i_signals_t) is 
  begin
    i.id_rst_i <= '0';
    i.cfg_i.valid <= '0';
    i.cfg_i.d <= (others => '0');
    i.pipeline_i.valid <= '0';
    i.pipeline_i.data <= (others => '0');
  end procedure;
  
  procedure test_configuration(
    signal i: out idec_i_signals_t; signal o: idec_o_signals_t) is
  begin
    assert
      o.cfg_o.valid='0'
      report "config output valid outside of configuration"
      severity error;
    -- write some registers
    i.cfg_i.valid <= '1';
    for j in 0 to C_CFG_INPUT_DECODER_REGISTER_COUNT-1 loop
      i.cfg_i.d <= conv_std_logic_vector(j+(2**10),C_CFG_WORD_SIZE);
      wait for C_CLK_PERIOD;
      assert
        o.cfg_o.valid='1'
        report "config output invalid while configurating"
        severity error;
    end loop;
    i.cfg_i.valid <= '0';

    assert 
      o.cfg_o.d=conv_std_logic_vector(2**10,C_CFG_WORD_SIZE)
      report "invalid config data output after configuration"
      severity error;

    -- do nothing (wait for some clock cycles)
    i.cfg_i.d <= x"baadf00d";
    wait for C_CLK_PERIOD*10;
    assert 
      o.cfg_o.d=conv_std_logic_vector(2**10,C_CFG_WORD_SIZE)
      report "invalid config data output after configuration"
      severity error;
    assert
      o.cfg_o.valid='0'
      report "config output valid outside of configuration"
      severity error;

    -- write some other registers and read back original input
    i.cfg_i.valid <= '1';
    for j in 0 to C_CFG_INPUT_DECODER_REGISTER_COUNT-1 loop
      i.cfg_i.d <= conv_std_logic_vector(j+(2**11),C_CFG_WORD_SIZE);
      assert 
        o.cfg_o.d=conv_std_logic_vector(j+(2**10),C_CFG_WORD_SIZE)
        report "invalid config data output while configuration"
        severity error;
      wait for C_CLK_PERIOD;
      assert
        o.cfg_o.valid='1'
        report "config output invalid while configurating"
        severity error;
    end loop;
    i.cfg_i.valid <= '0';
  end procedure;
  
begin
  
  uut: input_processor port map (
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

    test_configuration(i_signals,o_signals);
    -- no data path testing is performed here. instead use the hardware test
    -- ht_input_decoder: `ht_input_decoder.py -r`
    wait;
  end process;
  
end;
