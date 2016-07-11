library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library paco_lut;
use paco_lut.lut_package.all;

entity tb_bram_controller is
end entity;

architecture behavior of tb_bram_controller is
  constant C_CLK_PERIOD : time := 10 ns;
  
  signal clk : std_logic;

  type i_signals_t is record
    id_rst_i : std_logic;
    cfg_i : cfg_word_t;

    cfg_mode_i : std_logic;
    ram_addr_i : std_logic_vector(C_SEGMENT_BITS-1 downto 0);
    ram_data_i : std_logic_vector(C_LUT_BRAM_WIDTH-1 downto 0);
    ram_we_i : std_logic;

    pipeline_i : p_lut_t;
  end record;

  type o_signals_t is record
    cfg_o : cfg_word_t;
    pipeline_o : p_interpolator_t;
  end record;

  signal i_signals: i_signals_t;
  signal o_signals: o_signals_t;
   
  procedure init_signals(signal i: out i_signals_t) is 
  begin
    i.id_rst_i <= '0';
    i.cfg_i.valid <= '0';
    i.cfg_i.d <= (others => '0');
    i.cfg_mode_i <= '0';
    i.ram_addr_i <= (others => '0');
    i.ram_data_i <= (others => '0');
    i.ram_we_i <= '0';
    i.pipeline_i.valid <= '0';
    i.pipeline_i.address <= (others => '0');
    i.pipeline_i.selector <= (others => '0');
    i.pipeline_i.interpolator <= (others => '0');
  end procedure;

  procedure write_ram(
    signal i: out i_signals_t; signal o: in o_signals_t;
    enable: std_logic; we: std_logic; offset: integer ) is
  begin
    i.cfg_mode_i <= enable;
    for j in 0 to 2**C_SEGMENT_BITS-1 loop
      i.ram_addr_i <= conv_std_logic_vector(j,C_SEGMENT_BITS);
      i.ram_data_i <= 
        conv_std_logic_vector(j+offset,C_BASE_BITS) &
        conv_std_logic_vector(j+3+offset,C_INCLINE_BITS);

      i.ram_we_i <= we;
      wait for C_CLK_PERIOD;
      i.ram_we_i <= '0';
    end loop;
    i.cfg_mode_i <= '0';
  end procedure;
  procedure read_ram(
    signal i: out i_signals_t; signal o: in o_signals_t;
    offset: integer ) is
  begin
    i.cfg_mode_i <= '0';
    for j in 0 to 2**C_SEGMENT_BITS-1 loop
      i.pipeline_i.valid <= '1';
      i.pipeline_i.address <= conv_std_logic_vector(j,C_SEGMENT_BITS);
      i.pipeline_i.interpolator <= conv_std_logic_vector(j+1,C_INTERPOLATION_BITS);
      i.pipeline_i.selector <= conv_std_logic_vector(j+2,C_SELECTOR_BITS);
      wait for C_CLK_PERIOD;
      assert
        o.pipeline_o.selector/=conv_std_logic_vector(j+1,C_INTERPOLATION_BITS)
        report "selector was not relayed correctly"
        severity error;
      assert
        o.pipeline_o.interpolator/=conv_std_logic_vector(j+2,C_INTERPOLATION_BITS)
        report "interpolator was not relayed correctly"
        severity error;
      assert
        o.pipeline_o.base/=conv_std_logic_vector(j+offset,C_INTERPOLATION_BITS)
        report "incorrect base lookup"
        severity error;
      assert
        o.pipeline_o.incline/=conv_std_logic_vector(j+offset+3,C_INTERPOLATION_BITS)
        report "incorrect incline lookup"
        severity error;
      i.pipeline_i.valid <= '0';
    end loop;
    i.cfg_mode_i <= '0';
  end procedure;

begin
  
  uut: bram_controller port map (
    clk => clk,
    rst => i_signals.id_rst_i,

    cfg_i => i_signals.cfg_i,
    cfg_o => o_signals.cfg_o,
    cfg_mode_i => i_signals.cfg_mode_i,
    ram_addr_i => i_signals.ram_addr_i,
    ram_data_i => i_signals.ram_data_i,
    ram_we_i => i_signals.ram_we_i,
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
      
    write_ram(i_signals,o_signals, '1', '1', 4096);
    read_ram(i_signals,o_signals,4096);
    wait for C_CLK_PERIOD*10;
    write_ram(i_signals,o_signals, '0', '0', 1024);
    read_ram(i_signals,o_signals,4096);
    wait for C_CLK_PERIOD*10;
    write_ram(i_signals,o_signals, '1', '0', 2048);
    read_ram(i_signals,o_signals,4096);
    wait for C_CLK_PERIOD*10;
    write_ram(i_signals,o_signals, '0', '1', 8192);
    read_ram(i_signals,o_signals,4096);
    wait for C_CLK_PERIOD*10;



    wait;
  end process;
  
end;
