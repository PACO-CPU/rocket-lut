library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library work;
use work.lut_package.all;

entity tb_lut_controller is
end entity;

architecture behavior of tb_lut_controller is
  constant C_CLK_PERIOD : time := 10 ns;
  
  signal clk : std_logic := '0';
  
  type i_signals_t is record 
  
    id_rst_i : std_logic;
    id_stat_i : std_logic;
    id_exe_i : std_logic;
    id_cfg_i : std_logic;
    data_i : std_logic_vector(C_WORD_SIZE-1 downto 0);

  end record;
  
  type o_signals_t is record 
    status_o : std_logic_vector(C_WORD_SIZE-1 downto 0);
    error_o : std_logic;
    
    cfg_mode_o : std_logic;
    cfg_o : cfg_word_t;
    pipeline_o : p_input_t;
    lut_addr_o : std_logic_vector(C_SEGMENT_BITS-1 downto 0);
    lut_data_o : std_logic_vector(C_LUT_BRAM_WIDTH-1 downto 0);
    lut_we_o : std_logic;
  end record;
  
  signal i_signals : i_signals_t;
  signal o_signals : o_signals_t;
  
  procedure init_signals(signal i: out i_signals_t) is 
  begin
    i.id_rst_i <= '0';
    i.id_stat_i <= '0';
    i.id_exe_i <= '0';
    i.id_cfg_i <= '0';
    i.data_i <= (others => '0');
  end procedure;
  
  procedure test_status(
    signal i: out i_signals_t; signal o: o_signals_t;
    pipeline_count : integer; 
    cfg_count : integer;
    err: std_logic_vector) is
  begin
    i.id_stat_i <= '1';
    wait for C_CLK_PERIOD;
    i.id_stat_i <= '0';
    assert 
      o.status_o=
        conv_std_logic_vector(pipeline_count,8)&
        conv_std_logic_vector(cfg_count,16)&
        err
      report "unexpected status"
      severity error;
  end procedure;
  
  
  procedure configure_ram_partial(
    signal i: out i_signals_t; signal o: o_signals_t) is
  begin
    -- partially configure the ram: This serves to test if it resets properly
    -- with the reset we are going to perform below.
    i.id_cfg_i <= '1';
    assert o.cfg_mode_o='1' 
      report "cfg_mode_o unset during RAM configuration"
      ;
    assert o.error_o='0' 
      report "unexpected error condition"
      ;
    for j in 0 to C_CFG_LUT_REGISTER_COUNT-4 loop
      i.data_i <= conv_std_logic_vector(j,C_WORD_SIZE);
      wait for C_CLK_PERIOD;
      assert o.cfg_mode_o='1' 
         report "cfg_mode_o unset during RAM configuration";
      assert o.error_o='0'  report "unexpected error condition";
    end loop;
    i.id_cfg_i <= '0';
    test_status(i,o,0,C_CFG_LUT_REGISTER_COUNT-3,x"00");
  end procedure;
  
  procedure test_premature_execution(
    signal i: out i_signals_t; signal o: o_signals_t) is
  begin
    -- provoke an error by trying to execute prematurely
    assert o.cfg_mode_o='1' 
       report "cfg_mode_o unset during RAM configuration"
      severity error;
    assert o.error_o='0'  
      report "unexpected error condition"
      severity error;
    
    i.id_exe_i <= '1';
    wait for C_CLK_PERIOD;
    i.id_exe_i <= '0';
    
    assert o.error_o='1' 
       report "no error generated for exe in raw state";
    test_status(i,o,0,C_CFG_LUT_REGISTER_COUNT-3,x"02");
    
    -- reset
    
    i.id_rst_i <= '1';
    wait for C_CLK_PERIOD;
    i.id_rst_i <= '0';
    
    assert o.error_o='0' 
       report "error not reset after reset"
       severity error;
    test_status(i,o,0,0,x"00");
  end procedure;
  
  
  procedure test_config_error(
    signal i: out i_signals_t; signal o: o_signals_t) is
  begin
    -- provoke an error by trying to configure in 'ready' state
    assert o.cfg_mode_o='0' 
       report "cfg_mode_o set outside of RAM configuration"
      severity error;
    assert o.error_o='0'  
      report "unexpected error condition"
      severity error;
    
    i.id_cfg_i <= '1';
    wait for C_CLK_PERIOD;
    i.id_cfg_i <= '0';
    
    assert o.error_o='1' 
       report "no error generated for cfg in ready state";
    test_status(i,o,0,C_CFG_REGISTER_COUNT,x"01");
    
    -- reset
    
    i.id_rst_i <= '1';
    wait for C_CLK_PERIOD;
    i.id_rst_i <= '0';
    
    assert o.error_o='0' 
       report "error not reset after reset"
       severity error;
    test_status(i,o,0,0,x"00");
  end procedure;
  
  procedure configure_ram(
    signal i: out i_signals_t; signal o: o_signals_t) is
  begin
    -- configure the RAM
    test_status(i,o,0,0,x"00");
    i.id_cfg_i <= '1';
    assert o.cfg_mode_o='1' 
       report "cfg_mode_o unset during RAM configuration"
       severity error;
    assert o.error_o='0'
      report "unexpected error condition"
      severity error;
    for j in 0 to C_CFG_LUT_REGISTER_COUNT-1 loop
      i.data_i <= conv_std_logic_vector(j,C_WORD_SIZE);
      wait for C_CLK_PERIOD;
      assert o.cfg_mode_o='1' 
        report "cfg_mode_o unset during RAM configuration"
        severity error;
      assert o.error_o='0'  
        report "unexpected error condition"
        severity error;
    end loop;
    i.id_cfg_i <= '0';
    
    wait for C_CLK_PERIOD;
    assert o.cfg_mode_o='0' 
      report "cfg_mode_o not reset after RAM configuration"
      severity error;
    assert o.error_o='0'  
      report "unexpected error condition"
      severity error;
    
    test_status(i,o,0,C_CFG_LUT_REGISTER_COUNT,x"00");
    wait for C_CLK_PERIOD*20;
  end procedure;
  
  procedure configure_chain(
    signal i: out i_signals_t; signal o: o_signals_t) is
  begin
    -- configure the PLA and input preprocessor
    test_status(i,o,0,C_CFG_LUT_REGISTER_COUNT,x"00");
    i.id_cfg_i <= '1';
    assert o.cfg_mode_o='0' 
      report "cfg_mode_o is high outside of RAM configuration"
      severity warning;
    assert o.error_o='0' 
      report "unexpected error condition"
      severity error;
    assert o.cfg_o.valid='0' 
      report "cfg_o.valid is high prematurely"
      severity error;
    for j in 0 to C_CFG_CHAIN_REGISTER_COUNT-1 loop
      i.data_i <= conv_std_logic_vector(j+2**16,C_WORD_SIZE);
      wait for C_CLK_PERIOD;
      assert o.cfg_mode_o='0' 
        report "cfg_mode_o set during chain configuration"
        severity error;
      assert o.error_o='0'  
        report "unexpected error condition"
        severity error;
      assert o.cfg_o.d=conv_std_logic_vector(j+2**16,C_WORD_SIZE)  
        report "cfg_o.d invalid"
        severity error;
      assert o.cfg_o.valid='1'  
        report "cfg_o.valid unset"
        severity error;
    end loop;
    i.id_cfg_i <= '0';
    
    wait for C_CLK_PERIOD;
    assert o.cfg_o.valid='0'  
      report "cfg_o.valid not debounced"
      severity error;
    
    test_status(i,o,0,C_CFG_REGISTER_COUNT,x"00");
    wait for C_CLK_PERIOD*20;
    assert o.error_o='0'  
      report "unexpected error condition"
      severity error;
    
  end procedure;
  
  procedure test_compute_pipeline(
    signal i: out i_signals_t; signal o: o_signals_t) is
  begin
    test_status(i,o,0,C_CFG_REGISTER_COUNT,x"00");
    i.id_exe_i <= '1';
    assert o.cfg_mode_o='0' 
      report "cfg_mode_o is high outside of RAM configuration"
      severity warning;
    assert o.error_o='0' 
      report "unexpected error condition"
      severity error;
    assert o.cfg_o.valid='0' 
      report "cfg_o.valid is high outside of configuration"
      severity error;
    assert o.pipeline_o.valid='0'
      report "pipeline_o.valid is high prematurely"
      severity error;
    
    for j in 0 to 9 loop
      i.data_i <= conv_std_logic_vector(j+2**16+2**17,C_WORD_SIZE);
      wait for C_CLK_PERIOD;
      assert o.cfg_mode_o='0' 
        report "cfg_mode_o set during chain configuration"
        severity error;
      assert o.error_o='0'  
        report "unexpected error condition"
        severity error;
      assert o.pipeline_o.valid='1'
        report "pipeline_o.valid not set high after execution injection"
        severity error;
      
      -- this fails as a false positive. how does that happen?!
      assert 
        o.pipeline_o.data=conv_std_logic_vector(j+2**16+2**17,C_WORD_SIZE);
        report "pipeline_o.data appears invalid. CHECK MANUALLY"
        severity error;
    end loop;
    i.id_exe_i <= '0';
    
    wait for C_CLK_PERIOD;
    assert o.pipeline_o.valid='0'
      report "pipeline_o.valid not debounced"
      severity error;
    test_status(i,o,0,C_CFG_REGISTER_COUNT,x"00");
    
    wait for C_CLK_PERIOD*20;
    assert o.error_o='0'  
      report "unexpected error condition"
      severity error;
    
  end procedure;
  
begin

  
  uut: lut_controller port map (
    clk => clk,
    id_rst_i => i_signals.id_rst_i,
    id_stat_i => i_signals.id_stat_i,
    id_exe_i => i_signals.id_exe_i,
    id_cfg_i => i_signals.id_cfg_i,
    data_i => i_signals.data_i,

    status_o => o_signals.status_o,
    error_o => o_signals.error_o,
    
    cfg_mode_o => o_signals.cfg_mode_o,
    cfg_o => o_signals.cfg_o,
    lut_addr_o => o_signals.lut_addr_o,
    lut_data_o => o_signals.lut_data_o,
    lut_we_o   => o_signals.lut_we_o,
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
    
    configure_ram_partial(i_signals,o_signals);
    test_premature_execution(i_signals,o_signals);
    configure_ram(i_signals,o_signals);
    configure_chain(i_signals,o_signals);
    test_config_error(i_signals,o_signals);
    configure_ram(i_signals,o_signals);
    configure_chain(i_signals,o_signals);
    test_compute_pipeline(i_signals,o_signals);
    
    wait;
  end process;
  
end;
