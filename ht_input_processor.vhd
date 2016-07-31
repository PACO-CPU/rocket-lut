library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library work;
use work.lut_package.all;
use work.test_package.all;

entity ht_input_decoder is
  port (
    clk_p : in std_logic;
    clk_n : in std_logic;
    rst : in std_logic;

    rxd : in std_logic;
    txd : out std_logic;
    led : out std_logic_vector(7 downto 0)
  );
end entity;

architecture implementation of ht_input_decoder is
  signal clk : std_logic;

  signal word : std_logic_vector(C_WORD_SIZE-1 downto 0);
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

  signal i_signals: idec_i_signals_t;
  signal o_signals: idec_o_signals_t;

  signal input: std_logic_vector(C_INPUT_WORD_SIZE-1 downto 0);
  signal input_counter : integer;

begin
   
  clkdiv: entity work.clk_divider port map (
    CLK_IN1_P => clk_p,
    CLK_IN1_N => clk_n,
    CLK_OUT1 => clk
  );

  i_signals.id_rst_i <= rst;
  uut: input_processor port map (
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
              when CMD_COMPUTE_IDEC => 
                state_post_rx <= READ_NEXT_INPUT;
                state_post_tx <= IDLE;
                state <= RX_WORD;
                input_counter <= 0;

              when others =>
                ht_common_cmd(rx_data, tx_valid,tx_data);
            end case;
          end if;

        when RX_WORD =>
          if rx_valid='1' then
            word(word_counter*8+7 downto word_counter*8) <= rx_data;
            if word_counter=(C_WORD_SIZE/8)-1 then
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
            if word_counter=(C_WORD_SIZE/8)-1 then
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
          if input_counter+1=C_INPUT_WORDS then
            state <= WRITE_PIPELINE;
          else
            input_counter <= input_counter+1;
            state <= RX_WORD;
          end if;

        when WRITE_PIPELINE =>
          i_signals.pipeline_i.data <= input;
          i_signals.pipeline_i.valid <= '1';
          state <= WAIT_PIPELINE;
        when WAIT_PIPELINE =>
          if o_signals.pipeline_o.valid='1' then
            word <= (others => '0');
            word(C_INTERPOLATION_BITS-1 downto 0) <= 
              o_signals.pipeline_o.interpolator;
            word(
              C_INTERPOLATION_BITS+C_SELECTOR_BITS-1 downto 
              C_INTERPOLATION_BITS) <= o_signals.pipeline_o.selector;
            state <= TX_WORD;
          end if;
      end case;

    end if;
  end process;



end architecture;

