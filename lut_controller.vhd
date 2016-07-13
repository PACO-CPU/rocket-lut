library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library paco_lut;
use paco_lut.lut_package.all;

entity lut_controller is
  port (
    clk : in std_logic;
    id_rst_i : in std_logic;
    id_stat_i : in std_logic;
    id_exe_i : in std_logic;
    id_cfg_i : in std_logic;
    data_i : in std_logic_vector(C_INPUT_WORDS*C_WORD_SIZE-1 downto 0);

    status_o : out std_logic_vector(C_WORD_SIZE-1 downto 0);
    error_o : out std_logic;
    
    cfg_mode_o : out std_logic;
    cfg_o : out cfg_word_t;

    lut_addr_o : out std_logic_vector(C_SEGMENT_BITS-1 downto 0);
    lut_data_o : out std_logic_vector(C_LUT_BRAM_WIDTH-1 downto 0);
    lut_we_o   : out std_logic;

    pipeline_o : out p_input_t

  );
end entity;

architecture implementation of lut_controller is
  type state_t is ( STATE_CFG_RAM, STATE_CFG_CHAIN, STATE_READY, STATE_ERROR );
  signal state : state_t;
  
  signal cfg_count : integer;
  
  signal cfg_ram_addr : std_logic_vector(C_SEGMENT_BITS-1 downto 0);
  signal cfg_ram_buffer : std_logic_vector(
    C_RAM_CONFIG_BUFFER_SIZE_BITS-1 downto 0);
  signal cfg_ram_we : std_logic;
  signal cfg_ram_buffer_counter : integer range 0 to C_RAM_CONFIG_BUFFER_SIZE;

  
  signal e_invalid_cfg   : std_logic;
  signal e_premature_exe : std_logic;
  signal e_instr_code    : std_logic;
begin 
  
  error_o <= '1' when state=STATE_ERROR else '0';
  
  lut_data_o <= cfg_ram_buffer(
    C_RAM_CONFIG_BUFFER_SIZE_BITS - 1 downto 
    C_RAM_CONFIG_BUFFER_SIZE_BITS - C_LUT_BRAM_WIDTH);
  lut_we_o   <= cfg_ram_we;

  process(clk) is 
    -- highest bit of the ram buffer that needs to be written next
    variable ram_buffer_offset: integer;
  begin
    
    if rising_edge(clk) then
      
      -- some signals are set only in special circumstances. Reset them here:
      pipeline_o.valid <= '0';
      cfg_ram_we  <= '0';
      cfg_o.valid <= '0';
      cfg_mode_o  <= '0';

      ram_buffer_offset := 
        C_RAM_CONFIG_BUFFER_SIZE_BITS-1
        -(cfg_ram_buffer_counter mod C_RAM_CONFIG_BUFFER_SIZE)*C_CFG_WORD_SIZE;

      -- the following signals are also used only in special cases but otherwise
      -- they are don't cares: 
      --   lut_addr_o, lut_data_o,
      --   cfg_o.d
      
      -- delay new LUT addresses by one cycle
      lut_addr_o <= cfg_ram_addr;
      
      -- per-state signals
      case state is 
        when STATE_CFG_RAM => 
          cfg_mode_o <= '1';
        when others => 
          null;
      end case;
      
      -- we do not check if multiple id_*_i fields are set here because
      -- it's just some overhead we do not need right now.
      
      if id_rst_i='1' then -- perform a reset instruction
        state           <= STATE_CFG_RAM;
        cfg_mode_o      <= '1';
        cfg_count       <= 0;
        cfg_ram_addr    <= (others => '0');
        cfg_ram_buffer_counter <= 0;
        e_invalid_cfg   <= '0';
        e_premature_exe <= '0';
        e_instr_code    <= '0';

        
        -- status remains uninitialized as we do not need it outside of
        -- id_staT_i.

      elsif id_stat_i='1' then -- perform a status report instruction

        status_o <= (others => '0');
        -- todo: set status_o(31 downto 24) to pipeline fill level
        status_o(23 downto 8) <= conv_std_logic_vector(cfg_count,16);
        status_o(0) <= e_invalid_cfg;
        status_o(1) <= e_premature_exe;
        status_o(2) <= e_instr_code;
      
      elsif id_cfg_i='1' then -- perform a configure instruction
        case state is
          when STATE_CFG_RAM =>
            
            cfg_ram_buffer(
              ram_buffer_offset downto ram_buffer_offset-C_CFG_WORD_SIZE+1) <=
              data_i;

            cfg_count <= cfg_count +1;
            
            if cfg_ram_buffer_counter=C_RAM_CONFIG_BUFFER_SIZE-1 then
              cfg_ram_buffer_counter <= 0;
              cfg_ram_addr <= cfg_ram_addr +1; -- visible in the next cycle
              cfg_ram_we <= '1';


              if cfg_count+1=C_CFG_LUT_REGISTER_COUNT then
                state <= STATE_CFG_CHAIN;
              end if;
            else
              cfg_ram_buffer_counter <= cfg_ram_buffer_counter +1;
            end if;

          when STATE_CFG_CHAIN =>
            
            cfg_o.d <= data_i;
            cfg_count <= cfg_count +1;
            cfg_o.valid <= '1';
            
            if cfg_count+1=C_CFG_REGISTER_COUNT then
              state <= STATE_READY;
            end if;

          when others =>
            state <= STATE_ERROR;
            e_invalid_cfg <= '1';

        end case;

      elsif id_exe_i='1' then -- perform an execute instruction
        case state is
          when STATE_READY =>
            pipeline_o.data <= data_i;
            pipeline_o.valid <= '1';

          when others =>
            state <= STATE_ERROR;
            e_premature_exe <= '1';

        end case;
      
      end if;



    end if;
  end process;

end architecture;

