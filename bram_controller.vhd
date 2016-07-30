library ieee;
use ieee.std_logic_1164.all;

library paco_lut;
use paco_lut.lut_package.all;

--! @brief RAM i/o controller pipeline stage for the LUT HW core.
--! @details Performs a RAM lookup using the pipeline_i.address bitvector
--! as address. The RAM is written via a secondary interface spanning
--! cfg_mode_i, ram_addr_i, ram_data_i and ram_we_i. This interface takes
--! precedence over addresses visible on the pipeline interface whenever
--! cfg_mode_i is set high. If it is set low, write requests on that interface
--! are ignored.
--! As no further configurable bits exist in this pipeline stage, the config
--! interface is simply connected end-to-end.
entity bram_controller is
  port (
    clk : in std_logic;
    rst : in std_logic;
    
    cfg_i : in  cfg_word_t;
    cfg_o : out cfg_word_t;

    cfg_mode_i : in std_logic;
    ram_addr_i : in std_logic_vector(C_SEGMENT_BITS-1 downto 0);
    ram_data_i : in std_logic_vector(C_LUT_BRAM_WIDTH-1 downto 0);
    ram_we_i   : in std_logic;

    pipeline_i : in p_lut_t;
    pipeline_o : out p_interpolator_t

  );
end entity;

--! The nature of the block ram used as storage backend for this implementation
--! dictates the introduction of a delay cycle within this core. Further
--! delays are not configurable.
architecture implementation of bram_controller is
  signal mem_addr : std_logic_vector(C_SEGMENT_BITS-1 downto 0);
  signal mem_data_w : std_logic_vector(C_LUT_BRAM_WIDTH-1 downto 0);
  signal mem_data_r : std_logic_vector(C_LUT_BRAM_WIDTH-1 downto 0);
  signal mem_we : std_logic;
  

  type p_lut1_t is record
    valid : std_logic;
    selector : std_logic_vector(C_SELECTOR_BITS-1 downto 0);
    interpolator : std_logic_vector(C_INTERPOLATION_BITS-1 downto 0);
  end record;
  

  signal pipeline_1 : p_lut1_t;

begin
  cfg_o <= cfg_i; -- no configuration words for us ( not daisy-chained anyway )
  
  -- each cell stores a word base & incline.
  mem: single_port_ram generic map (
    DATA_WIDTH => C_LUT_BRAM_WIDTH,
    ADDR_WIDTH => C_SEGMENT_BITS
  ) port map (
    clk => clk,
    port1_addr => mem_addr,
    port1_data_w => mem_data_w,
    port1_data_r => mem_data_r,
    port1_we     => mem_we
  );
  
  -- perform multiplexing between the pipeline and configuration RAM interfaces.
  mem_addr <= ram_addr_i when cfg_mode_i='1' else pipeline_i.address;
  -- mem_data_w is a don't care as long ram_we is low and the pipeline will
  -- never attempt to write. Thus set it to ram_data_i
  mem_data_w <= ram_data_i;
  -- a write occurs iff the configuration interface is active and requests a
  -- write operation
  mem_we     <= ram_we_i and cfg_mode_i;

  process(clk) is begin
    if rising_edge(clk) then
      -- delay stage parallel to the mem interface. we need to pass through
      -- the valid, selector and interpolator values, the address itself is
      -- not needed anymore and thus dropped here.
      pipeline_1.valid <= pipeline_i.valid;
      pipeline_1.selector <= pipeline_i.selector;
      pipeline_1.interpolator <= pipeline_i.interpolator;
      

      if rst='1' then
        pipeline_1.valid <= '0';
       -- pipeline_o.valid <= '0';
      end if;

    end if;
  end process;
  
  -- output stage
  -- take valid, selector and interpolator from the delay slot (above) and the
  -- looked-up word comes from the memory block.
  pipeline_o.valid <= pipeline_1.valid;
  pipeline_o.selector <= pipeline_1.selector;
  pipeline_o.interpolator <= pipeline_1.interpolator;
  pipeline_o.base <= mem_data_r(C_LUT_BRAM_WIDTH-1 downto C_INCLINE_BITS);
  pipeline_o.incline <= mem_data_r(C_INCLINE_BITS-1 downto 0);
end architecture;

