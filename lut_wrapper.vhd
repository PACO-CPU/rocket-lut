
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lut_package.all;

--! @brief Interface for instantiating multiple lut_core instances and managing
--! three-input words via two-input instructions.
entity lut_wrapper is
  port (
    clk : in std_logic;
    
    lutsel_i : in std_logic_vector(4 downto 0);

    id_rst_i : in std_logic;
    id_stat_i : in std_logic;
    id_exe_i : in std_logic;
    id_cfg_i : in std_logic;
    data_i : in std_logic_vector(C_WORD_SIZE-1 downto 0); -- rs1
    data2_i : in std_logic_vector(C_WORD_SIZE-1 downto 0); -- rs2
    charm_i : in std_logic;
    strange_i : in std_logic_vector(1 downto 0);
    data_we_i : in std_logic;

    data_o : out std_logic_vector(C_WORD_SIZE-1 downto 0); -- rd
    data_valid_o : out std_logic;
    
    status_o : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    error_o : out std_logic

  );
end entity;

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.lut_package.all;

entity chain_core is
  generic (
    G_INDEX : integer := 0
  );
  port (
    clk : in std_logic;
    cs_i : in std_logic_vector(C_LUT_CORE_COUNT-1 downto 0);
    id_rst_i : in std_logic;
    id_stat_i : in std_logic;
    id_exe_i : in std_logic;
    id_cfg_i : in std_logic;
    rs1_i : in std_logic_vector(C_WORD_SIZE-1 downto 0); -- rs1
    rs2_i : in std_logic_vector(C_WORD_SIZE-1 downto 0); -- rs2
    we_i : in std_logic;
    charm_i : in std_logic;
    strange_i : in std_logic_vector(1 downto 0);
    data_o : out std_logic_vector(C_WORD_SIZE-1 downto 0); -- rd
    data_valid_o : out std_logic;
    status_o : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    error_o : out std_logic
  );
end entity;

architecture implementation of chain_core is


  signal this_data_o : std_logic_vector(C_WORD_SIZE-1 downto 0); -- rd
  signal this_data_valid_o : std_logic;
  signal this_status_o : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal this_error_o :  std_logic;

  signal next_data_o : std_logic_vector(C_WORD_SIZE-1 downto 0); -- rd
  signal next_data_valid_o : std_logic;
  signal next_status_o : std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal next_error_o : std_logic;

  signal cs : std_logic;
  signal cs_delay : std_logic_vector(0 to C_DATAPATH_DELAY);
  signal cs_output : std_logic;

  signal wr_delay : std_logic;
  
  type input_t is array(0 to 2) of std_logic_vector(C_WORD_SIZE-1 downto 0);
  signal cur_data : input_t;
  signal last_data : input_t;

begin
  
  cs <= cs_i(G_INDEX);
  cs_delay(0) <= cs;
  cs_output <= cs_delay(C_DATAPATH_DELAY);
  
  process(clk) is begin
    if rising_edge(clk) then
      wr_delay <= cs and we_i;
      if (cs and we_i)='1' then --wr_delay='1' then
        last_data <= cur_data;
      end if;
      for i in 1 to C_DATAPATH_DELAY loop
        cs_delay(i) <= cs_delay(i-1);
      end loop;
    end if;
  end process;
  

  cur_data(0) <= 
    rs1_i when charm_i&strange_i="000" else
    rs1_i when charm_i&strange_i="100" else
    rs2_i when charm_i&strange_i="110" else
    last_data(0);
  cur_data(1) <= 
    rs1_i when charm_i&strange_i="001" else
    rs1_i when charm_i&strange_i="101" else
    rs2_i when charm_i&strange_i="100" else
    last_data(1);
  cur_data(2) <= 
    rs1_i when charm_i&strange_i="010" else
    rs1_i when charm_i&strange_i="110" else
    rs2_i when charm_i&strange_i="101" else
    last_data(2);

  
  this_core: lut_core port map (
    clk => clk,
    id_rst_i => id_rst_i and cs,
    id_stat_i => id_stat_i and cs,
    id_exe_i => id_exe_i and cs,
    id_cfg_i => id_cfg_i and cs,
    data_i => cur_data(0),
    data2_i => cur_data(1),
    data3_i => cur_data(2),
    data_o => this_data_o,
    data_valid_o => this_data_valid_o,
    status_o => this_status_o,
    error_o => this_error_o
  );
  
  next_chain_gen: if G_INDEX+1<C_LUT_CORE_COUNT generate
    next_chain: entity work.chain_core generic map (
      G_INDEX => G_INDEX+1
    ) port map (
      clk => clk,
      cs_i => cs_i,
      id_rst_i => id_rst_i,
      id_stat_i => id_stat_i,
      id_exe_i => id_exe_i,
      id_cfg_i => id_cfg_i,
      rs1_i => rs1_i,
      rs2_i => rs2_i,
      we_i => we_i,
      charm_i => charm_i,
      strange_i => strange_i,
      data_o => next_data_o,
      data_valid_o => next_data_valid_o,
      status_o => next_status_o,
      error_o => next_error_o
    );

    data_o       <= this_data_o when cs_output='1' else next_data_o;
    data_valid_o <= this_data_valid_o when cs_output='1' else next_data_valid_o;
    status_o     <= this_status_o when cs_output='1' else next_status_o;
    error_o      <= this_error_o when cs_output='1' else next_error_o;

    
  end generate;

  terminator_gen : if G_INDEX+1>=C_LUT_CORE_COUNT generate
    data_o       <= this_data_o;
    data_valid_o <= this_data_valid_o;
    status_o     <= this_status_o;
    error_o      <= this_error_o;
  end generate;

end architecture;


architecture implementation of lut_wrapper is
  signal lutsel_ext : std_logic_vector(4 downto 0);
  signal cs_ext : std_logic_vector(31 downto 0);
  signal cs : std_logic_vector(C_LUT_CORE_COUNT-1 downto 0);
begin
  lutsel_ext <= lutsel_i;
--  lutsel_ext(4 downto C_LUT_CORE_COUNT_BITS) <= (others => '0');
--  lutsel_ext(C_LUT_CORE_COUNT_BITS-1 downto 0) <= lutsel_i;
  
  cs_ext <=
    x"00000001" when lutsel_ext="00000" else
    x"00000002" when lutsel_ext="00001" else
    x"00000004" when lutsel_ext="00010" else
    x"00000008" when lutsel_ext="00011" else
    x"00000010" when lutsel_ext="00100" else
    x"00000020" when lutsel_ext="00101" else
    x"00000040" when lutsel_ext="00110" else
    x"00000080" when lutsel_ext="00111" else
    x"00000100" when lutsel_ext="01000" else
    x"00000200" when lutsel_ext="01001" else
    x"00000400" when lutsel_ext="01010" else
    x"00000800" when lutsel_ext="01011" else
    x"00001000" when lutsel_ext="01100" else
    x"00002000" when lutsel_ext="01101" else
    x"00004000" when lutsel_ext="01110" else
    x"00008000" when lutsel_ext="01111" else
    x"00010000" when lutsel_ext="10000" else
    x"00020000" when lutsel_ext="10001" else
    x"00040000" when lutsel_ext="10010" else
    x"00080000" when lutsel_ext="10011" else
    x"00100000" when lutsel_ext="10100" else
    x"00200000" when lutsel_ext="10101" else
    x"00400000" when lutsel_ext="10110" else
    x"00800000" when lutsel_ext="10111" else
    x"01000000" when lutsel_ext="11000" else
    x"02000000" when lutsel_ext="11001" else
    x"04000000" when lutsel_ext="11010" else
    x"08000000" when lutsel_ext="11011" else
    x"10000000" when lutsel_ext="11100" else
    x"20000000" when lutsel_ext="11101" else
    x"40000000" when lutsel_ext="11110" else
    x"80000000";
  
  cs <= cs_ext(C_LUT_CORE_COUNT-1 downto 0);

  first_chain: entity work.chain_core generic map (
    G_INDEX => 0
  ) port map (
    clk => clk,
    cs_i => cs,
    id_rst_i => id_rst_i,
    id_stat_i => id_stat_i,
    id_exe_i => id_exe_i,
    id_cfg_i => id_cfg_i,
    rs1_i => data_i,
    rs2_i => data2_i,
    we_i => data_we_i,
    charm_i => charm_i,
    strange_i => strange_i,
    data_o => data_o,
    data_valid_o => data_valid_o,
    status_o => status_o,
    error_o => error_o
  );
end architecture;
