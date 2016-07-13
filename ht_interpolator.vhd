library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library paco_lut;
use paco_lut.lut_package.all;
use paco_lut.test_package.all;

entity ht_interpolator is
  port (
    clk : in std_logic;
    rst : in std_logic;

    rxd : in std_logic;
    txd : out std_logic;
    led : out std_logic_vector(7 downto 0)
  );
end entity;

architecture implementation of ht_interpolator is
  constant C_INTER_BITS : integer := 
    C_SELECTOR_BITS+C_INTERPOLATION_BITS+C_BASE_BITS+C_INCLINE_BITS;
  constant C_INTER_WORDS : integer :=
    cdiv(C_INTER_BITS,32);
  
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
    WRITE_CONFIG_WORD,
    READ_NEXT_INPUT,
    WRITE_PIPELINE,WAIT_PIPELINE);
  signal state : state_t;
  signal state_post_rx : state_t;
  signal state_post_tx : state_t;

  signal i_signals: inter_i_signals_t;
  signal o_signals: inter_o_signals_t;

  signal input: std_logic_vector(C_INTER_WORDS*32-1 downto 0);
  signal input_counter : integer;

begin
  
  i_signals.id_rst_i <= rst;
  uut: interpolator port map (
    clk => clk,
    rst => i_signals.id_rst_i,

    cfg_i => i_signals.cfg_i,
    cfg_o => o_signals.cfg_o,

    pipeline_i => i_signals.pipeline_i,
    pipeline_o => o_signals.pipeline_o
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
    x"88" when state=WRITE_CONFIG_WORD else
    x"90" when state=WRITE_PIPELINE else
    x"a0" when state=WAIT_PIPELINE else
    x"c0" when state=READ_NEXT_INPUT else
    x"80";

  process(clk,rst) is begin
    if rst='1' then
      state <= IDLE;
      word_counter <= 0;
      i_signals.cfg_i.valid <= '0';
      i_signals.pipeline_i.valid <= '0';
      tx_valid <= '0';

    elsif rising_edge(clk) then
      i_signals.cfg_i.valid <= '0';
      i_signals.pipeline_i.valid <= '0';
      tx_valid <= '0';
      case state is
        when IDLE =>
          if rx_valid='1' then
            case rx_data is
              when CMD_ECHO => 
                state_post_rx <= TX_WORD;
                state_post_tx <= IDLE;
                state <= RX_WORD;
              when CMD_CFG_WORD =>
                state_post_rx <= WRITE_CONFIG_WORD;
                state_post_tx <= IDLE;
                state <= RX_WORD;
              when CMD_COMPUTE_INTER => 
                state_post_rx <= READ_NEXT_INPUT;
                state_post_tx <= IDLE;
                state <= RX_WORD;
                input_counter <= 0;
              
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

        when WRITE_CONFIG_WORD =>
          i_signals.cfg_i.valid <= '1';
          i_signals.cfg_i.d <= word;
          word <= o_signals.cfg_o.d;
          state <= TX_WORD;
        
        when READ_NEXT_INPUT =>
          input(
            input_counter*C_WORD_SIZE+C_WORD_SIZE-1 downto 
            input_counter*C_WORD_SIZE) <= word;
          if input_counter+1=C_INTER_WORDS then
            state <= WRITE_PIPELINE;
          else
            input_counter <= input_counter+1;
            state <= RX_WORD;
          end if;

        when WRITE_PIPELINE =>
          i_signals.pipeline_i.valid <= '1';
          i_signals.pipeline_i.selector <= 
            input(
              C_SELECTOR_BITS+C_INTERPOLATION_BITS+C_BASE_BITS+C_INCLINE_BITS-1
              downto 
              C_INTERPOLATION_BITS+C_BASE_BITS+C_INCLINE_BITS);
          i_signals.pipeline_i.interpolator <= 
            input(
              C_INTERPOLATION_BITS+C_BASE_BITS+C_INCLINE_BITS-1
              downto 
              C_BASE_BITS+C_INCLINE_BITS);
          i_signals.pipeline_i.base <= 
            input(
              C_BASE_BITS+C_INCLINE_BITS-1
              downto 
              C_INCLINE_BITS);
          i_signals.pipeline_i.incline <= 
            input(
              C_INCLINE_BITS-1
              downto 
              0);
          state <= WAIT_PIPELINE;
        when WAIT_PIPELINE =>
          if o_signals.pipeline_o.valid='1' then
            word <= o_signals.pipeline_o.data;
            state <= TX_WORD;
          end if;
      end case;

    end if;
  end process;



end architecture;

