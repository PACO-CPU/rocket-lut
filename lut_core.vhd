
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lut_package.all;

--! @brief Top-level module for the LUT HW core
--! @details This module connects directly to the processor pipeline or
--! appropriate test benches / hardware tests.
entity lut_core is
  port (
    clk : in std_logic;
    id_rst_i : in std_logic;
    id_stat_i : in std_logic;
    id_exe_i : in std_logic;
    id_cfg_i : in std_logic;
    data_i : in std_logic_vector(C_WORD_SIZE-1 downto 0); -- rs1
    data2_i : in std_logic_vector(C_WORD_SIZE-1 downto 0); -- rs2
    data3_i : in std_logic_vector(C_WORD_SIZE-1 downto 0); -- rs3

    data_o : out std_logic_vector(C_WORD_SIZE-1 downto 0); -- rd
    data_valid_o : out std_logic;
    
    status_o : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    error_o : out std_logic

  );
end entity;

architecture implementation of lut_core is
  constant C_INPUT_BUFFER_SIZE : integer := max(3,C_INPUT_WORDS)*C_WORD_SIZE;
  signal input_data : std_logic_vector(C_INPUT_BUFFER_SIZE-1 downto 0);
  signal ctrl_cfg_mode_o : std_logic;
  signal ctrl_cfg_o : cfg_word_t;
  signal ctrl_pipeline_o : p_input_t;
  signal ctrl_lut_addr_o : std_logic_vector(C_SEGMENT_BITS-1 downto 0);
  signal ctrl_lut_data_o : std_logic_vector(C_LUT_BRAM_WIDTH-1 downto 0);
  signal ctrl_lut_we_o : std_logic;


  signal inproc_cfg_o : cfg_word_t;
  signal inproc_pipeline_o : p_pla_t;

  signal pla_cfg_o : cfg_word_t;
  signal pla_pipeline_o : p_lut_t;

  signal lut_cfg_o : cfg_word_t;
  signal lut_pipeline_o : p_interpolator_t;

  signal inter_cfg_o : cfg_word_t;
  signal inter_pipeline_o : p_output_t;
  
  signal reg1v : std_logic;
  signal reg1 : std_logic_vector(C_WORD_SIZE-1 downto 0);

begin
  input_data(C_INPUT_BUFFER_SIZE-1 downto 3*C_WORD_SIZE) <= (others => '0');
  input_data(3*C_WORD_SIZE-1 downto 0) <= data3_i & data2_i & data_i;
  
  ctrl: lut_controller port map (
    clk => clk,
    id_rst_i => id_rst_i,
    id_stat_i => id_stat_i,
    id_exe_i => id_exe_i,
    id_cfg_i => id_cfg_i,
    data_i => input_data(C_INPUT_WORDS*C_WORD_SIZE-1 downto 0),

    status_o => status_o,
    error_o => error_o,
    
    cfg_mode_o => ctrl_cfg_mode_o,
    cfg_o => ctrl_cfg_o,
    lut_addr_o => ctrl_lut_addr_o,
    lut_data_o => ctrl_lut_data_o,
    lut_we_o   => ctrl_lut_we_o,
    pipeline_o => ctrl_pipeline_o
  );

  inproc : input_processor port map (
    clk => clk,
    rst => id_rst_i,
    cfg_i => ctrl_cfg_o,
    cfg_o => inproc_cfg_o,

    pipeline_i => ctrl_pipeline_o,
    pipeline_o => inproc_pipeline_o
  );

  pla : address_translator port map (
    clk => clk,
    rst => id_rst_i,
    cfg_i => inproc_cfg_o,
    cfg_o => pla_cfg_o,

    pipeline_i => inproc_pipeline_o,
    pipeline_o => pla_pipeline_o
  );
  
  lut : bram_controller port map (
    clk => clk,
    rst => id_rst_i,
    cfg_i => pla_cfg_o,
    cfg_o => lut_cfg_o,

    cfg_mode_i => ctrl_cfg_mode_o,
    ram_addr_i => ctrl_lut_addr_o,
    ram_data_i => ctrl_lut_data_o,
    ram_we_i => ctrl_lut_we_o,

    pipeline_i => pla_pipeline_o,
    pipeline_o => lut_pipeline_o
  );

  inter: interpolator port map (
    clk => clk,
    rst => id_rst_i,
    cfg_i => lut_cfg_o,
    cfg_o => inter_cfg_o,

    pipeline_i => lut_pipeline_o,
    pipeline_o => inter_pipeline_o
  );

  

  data_o <= inter_pipeline_o.data;
  data_valid_o <= inter_pipeline_o.valid;

--  process (clk) is begin
--    if rising_edge(clk) then
--      if id_exe_i='1' then
--        reg1 <= not data_i;
--      else
--        reg1 <= (others => '0');
--      end if;
--      reg1v <= id_exe_i;
--    end if;
--  end process;
--
--  data_o <= reg1;
--  data_valid_o <= reg1v;
end architecture;
