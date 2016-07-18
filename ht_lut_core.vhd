library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library paco_lut;
use paco_lut.lut_package.all;
use paco_lut.test_package.all;

entity ht_lut_core is
  port (
    clk_p : in std_logic;
    clk_n : in std_logic;
    rst : in std_logic;

    rxd : in std_logic;
    txd : out std_logic;
    led : out std_logic_vector(7 downto 0)
  );
end entity;

architecture implementation of ht_lut_core is
  signal clk : std_logic;

  signal word : std_logic_vector(31 downto 0);
  signal word_counter : integer;

  signal rx_valid : std_logic;
  signal rx_data  : std_logic_vector(7 downto 0);
  signal tx_valid : std_logic;
  signal tx_ready : std_logic;
  signal tx_data  : std_logic_vector(7 downto 0);

  type state_t is (
    IDLE,
    RX_WORD,TX_WORD,
    
    RST_EXEC,
    STAT_EXEC,
    STAT_WAIT,
    CFG_EXEC,
    EXE_EXEC,
    EXE_NEXT_WORD,
    EXE_WAIT
    
    );

  signal state : state_t;
  signal state_post_rx : state_t;
  signal state_post_tx : state_t;
  signal state_post_exe : state_t;

  signal i_signals: core_i_signals_t;
  signal o_signals: core_o_signals_t;

  signal input: std_logic_vector(C_INPUT_WORD_SIZE-1 downto 0);
  signal input_counter : integer;
  signal output_counter : integer range 0 to (2**31)-1;

  signal stat_wait_counter : integer;

  signal clock_counter : integer range 0 to (2**31)-1;

  
begin
  
  clkdiv: entity work.clk_divider port map (
    CLK_IN1_P => clk_p,
    CLK_IN1_N => clk_n,
    CLK_OUT1 => clk
  );
  
  uut: lut_core port map (
    clk => clk,
    
    id_rst_i => i_signals.id_rst_i,
    id_stat_i => i_signals.id_stat_i,
    id_exe_i => i_signals.id_exe_i,
    id_cfg_i => i_signals.id_cfg_i,
    
    data_i => i_signals.data_i,
    data2_i => i_signals.data2_i,
    data3_i => i_signals.data3_i,

    data_o => o_signals.data_o,
    data_valid_o => o_signals.data_valid_o,
    
    status_o => o_signals.status_o,
    error_o => o_signals.error_o
  );


  rx : uart_receiver generic map (
    CLK_FREQ => C_CLK_FREQ,
    BAUD_RATE => C_BAUD_RATE
  ) port map (
    clk => clk,
    rst => rst,
    rxd => rxd,

    valid => rx_valid,
    do    => rx_data
  );

  tx : uart_transmitter generic map (
    CLK_FREQ => C_CLK_FREQ,
    BAUD_RATE => C_BAUD_RATE
  ) port map (
    clk => clk,
    rst => rst,
    txd => txd,
    di => tx_data,
    valid => tx_valid,
    ready => tx_ready
  );

  led <=
    x"81" when state=IDLE else
    x"82" when state=RX_WORD else
    x"84" when state=TX_WORD else
    x"80";

  process(clk,rst) is begin
    if rst='1' then
      state <= IDLE;
      word_counter <= 0;
      i_signals.id_rst_i <= '0';
      i_signals.id_stat_i <= '0';
      i_signals.id_exe_i <= '0';
      i_signals.id_cfg_i <= '0';
      tx_valid <= '0';
      output_counter <= 0;

    elsif rising_edge(clk) then
      i_signals.id_rst_i <= '0';
      i_signals.id_stat_i <= '0';
      i_signals.id_exe_i <= '0';
      i_signals.id_cfg_i <= '0';
      tx_valid <= '0';
      if (o_signals.data_valid_o='1') then
        output_counter <= output_counter +1;
      end if;
      case state is
        when IDLE =>
          if rx_valid='1' then
            case rx_data is
              when CMD_ECHO => 
                state_post_rx <= TX_WORD;
                state_post_tx <= IDLE;
                state <= RX_WORD;
              when CMD_CORE_RST => 
                state <= RST_EXEC;
              when CMD_CORE_STAT => 
                state <= STAT_EXEC;
              when CMD_CORE_EXE => 
                state_post_rx <= EXE_NEXT_WORD;
                state_post_tx <= IDLE;
                state <= RX_WORD;
                input_counter <= 0;
              when CMD_CORE_CFG => 
                state_post_rx <= CFG_EXEC;
                state_post_tx <= IDLE;
                state_post_exe <= EXE_WAIT;
                state <= RX_WORD;
              when CMD_CORE_EXE_BEGIN => 
                state_post_rx <= EXE_NEXT_WORD;
                state_post_tx <= IDLE;
                state_post_exe <= IDLE;
                state <= RX_WORD;
                input_counter <= 0;

              when CMD_DIAG_CLOCK_COUNTER => 
                state_post_tx <= IDLE;
                state <= TX_WORD;
                word <= conv_std_logic_vector(clock_counter,32);


              when CMD_DIAG_OUTPUT_COUNTER => 
                state_post_tx <= IDLE;
                state <= TX_WORD;
                word <= conv_std_logic_vector(output_counter,32);

              when CMD_CFG_INPUT_WORDS =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_INPUT_WORDS,8);
              when CMD_CFG_SELECTOR_BITS =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_SELECTOR_BITS,8);
              when CMD_CFG_INTERPOLATION_BITS =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_INTERPOLATION_BITS,8);
              when CMD_CFG_SEGMENT_BITS =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_SEGMENT_BITS,8);
              when CMD_CFG_PLA_INTERCONNECTS =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_PLA_INTERCONNECTS,8);
              when CMD_CFG_BASE_BITS =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_BASE_BITS,8);
              when CMD_CFG_INCLINE_BITS =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_INCLINE_BITS,8);
              when CMD_CFG_INPUT_DECODER_DELAY =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_INPUT_DECODER_DELAY,8);
              when CMD_CFG_ADDRESS_TRANSLATOR_DELAY =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_ADDRESS_TRANSLATOR_DELAY,8);
              when CMD_CFG_INTERPOLATOR_DELAY =>
                tx_valid <= '1';
                tx_data <= conv_std_logic_vector(C_INTERPOLATOR_DELAY,8);
              when others =>
                tx_valid <= '1';
                tx_data <= rx_data;
            end case;
          end if;

        when RX_WORD =>
          if rx_valid='1' then
            word(word_counter*8+7 downto word_counter*8) <= rx_data;
            if word_counter=3 then
              state <= state_post_rx;
              word_counter <= 0;
            else
              word_counter <= word_counter+1;
            end if;
          end if;

        when TX_WORD =>
          tx_valid <= '1';
          tx_data <= word(word_counter*8+7 downto word_counter*8);
          if (tx_valid='1') and (tx_ready='1') then
            if word_counter=3 then
              tx_valid <= '0';
              word_counter <= 0;
              state <= state_post_tx;
            else
              word_counter <= word_counter+1;
              tx_data <= word(word_counter*8+15 downto word_counter*8+8);
            end if;
          end if;
        
        when RST_EXEC =>
          i_signals.id_rst_i <= '1';
          state <= IDLE;
        
        when STAT_EXEC =>
          i_signals.id_stat_i <= '1';
          state <= STAT_WAIT;
          stat_wait_counter <= 1;
        when STAT_WAIT =>
          if stat_wait_counter=0 then
            word <= o_signals.status_o;
            state <= TX_WORD;
          else
            stat_wait_counter <= stat_wait_counter -1;
          end if;

        when CFG_EXEC =>
          i_signals.data_i <= word;
          i_signals.id_cfg_i <= '1';
          state <= IDLE;
        
        when EXE_NEXT_WORD =>
          input(
            input_counter*C_WORD_SIZE+C_WORD_SIZE-1 downto 
            input_counter*C_WORD_SIZE) <= word;
          if input_counter+1=C_INPUT_WORDS then
            state <= EXE_EXEC;
          else
            input_counter <= input_counter+1;
            state <= RX_WORD;
          end if;
        when EXE_EXEC =>
          i_signals.data_i <= input(C_WORD_SIZE-1 downto 0);
          i_signals.data2_i <= input(C_WORD_SIZE*2-1 downto C_WORD_SIZE);
          i_signals.data3_i <= input(C_WORD_SIZE*3-1 downto C_WORD_SIZE*2);
          i_signals.id_exe_i <= '1';
          state <= state_post_exe;
          clock_counter <= 0;
        when EXE_WAIT => 
          clock_counter <= clock_counter +1;
          if o_signals.data_valid_o='1' then
            word <= o_signals.data_o;
            state <= TX_WORD;
          end if;
      end case;

    end if;
  end process;



end architecture;

