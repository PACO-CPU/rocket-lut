library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library paco_lut;
use paco_lut.lut_package.all;
use paco_lut.test_package.all;

entity tb_address_translator is
end entity;

architecture behavior of tb_address_translator is
  constant C_CLK_PERIOD : time := 10 ns;
  
  signal clk : std_logic;

  signal i_signals: pla_i_signals_t;
  signal o_signals: pla_o_signals_t;
   
  procedure init_signals(signal i: out pla_i_signals_t) is 
  begin
    i.id_rst_i <= '0';
    i.cfg_i.valid <= '0';
    i.cfg_i.d <= (others => '0');
    i.pipeline_i.valid <= '0';
    i.pipeline_i.interpolator <= (others => '0');
    i.pipeline_i.selector <= (others => '0');
  end procedure;
  
  procedure test_configuration(
    signal i: out pla_i_signals_t; signal o: pla_o_signals_t) is
  begin
    assert
      o.cfg_o.valid='0'
      report "config output valid outside of configuration"
      severity error;
    -- write some registers
    i.cfg_i.valid <= '1';
    for j in 0 to C_CFG_PLA_REGISTER_COUNT-1 loop
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
    for j in 0 to C_CFG_PLA_REGISTER_COUNT-1 loop
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
  
  procedure reset(
    signal i: out pla_i_signals_t; signal o: pla_o_signals_t) is
  begin
    i.id_rst_i <= '1';
    wait for C_CLK_PERIOD;
    i.id_rst_i <= '0';
  end procedure;

  procedure configure_and_incremental(
    signal i: out pla_i_signals_t; signal o: pla_o_signals_t) is
  begin
    i.cfg_i.valid <= '1';
    -- configure AND plane
    for j in 0 to C_PLA_INTERCONNECTS-1 loop
      i.cfg_i.d <= conv_std_logic_vector(j,C_CFG_WORD_SIZE);
      wait for C_CLK_PERIOD;
      if C_CFG_PLA_AND_REGISTERS_PER_ROW>1 then
        i.cfg_i.d <= (others => '0');
        wait for C_CLK_PERIOD*(C_CFG_PLA_AND_REGISTERS_PER_ROW-1);
      end if;
    end loop;
    i.cfg_i.valid <= '0';
  end procedure;
  procedure configure_or_single(
    signal i: out pla_i_signals_t; signal o: pla_o_signals_t;
    v: std_logic_vector) is
  begin
    i.cfg_i.valid <= '1';
    -- configure OR plane
    i.cfg_i.d <= v;
    wait for C_CLK_PERIOD;
    i.cfg_i.d <= (others => '0');
    if C_SEGMENT_BITS>1 then
      wait for C_CLK_PERIOD*(C_SEGMENT_BITS-1);
    end if;
    i.cfg_i.valid <= '0';
  end procedure;


  procedure test_pla_1(
    signal i: out pla_i_signals_t; signal o: pla_o_signals_t) is
  begin
    reset(i,o);

    for j in 0 to 2**C_PLA_INTERCONNECTS-1 loop
      configure_or_single(i,o,conv_std_logic_vector(j,C_CFG_WORD_SIZE));
      configure_and_incremental(i,o);
      
      i.pipeline_i.valid <= '1';
      for k in 0 to 2**C_SELECTOR_BITS-1 loop
        i.pipeline_i.selector <= conv_std_logic_vector(k,C_SELECTOR_BITS);
        wait for C_CLK_PERIOD;
      end loop;
      i.pipeline_i.valid <= '0';
    end loop;
    

  end procedure;
  
begin
  
  uut: address_translator port map (
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
    -- this performs some rudimentary test case to be evaluated MANUALLY.
    -- for more thorough testing, synthesize using ht_address_translator as
    -- top-level module and use `ht_address_translator.py -r` to run automated
    -- testing.
    test_pla_1(i_signals,o_signals);

    wait;
  end process;
  
end;
