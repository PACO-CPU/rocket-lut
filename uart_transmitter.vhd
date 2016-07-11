library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity uart_transmitter is
	generic(
		CLK_FREQ  : integer := 50000000;
		BAUD_RATE : integer := 9600
	);
	port(
		clk : in  STD_LOGIC;
		rst : in  STD_LOGIC;
		txd : out std_logic;
		di    : in  STD_LOGIC_VECTOR (7 downto 0);
		valid : in  STD_LOGIC;
		ready : out  STD_LOGIC
	);
end uart_transmitter;

architecture Behavioral of uart_transmitter is
	signal tick: std_logic;
  signal send_state: integer range -2 to 9;
  signal ready_o : std_logic;
  signal data : std_logic_vector(7 downto 0);
begin

	baud_rate_gen_i : entity work.baud_rate_generator
	generic map (
		CLK_FREQ => CLK_FREQ,
		BAUD_RATE => BAUD_RATE
	)
	port map (
		clk => clk,
		rst => rst,
		tick => tick
	);
  ready <= ready_o;	
  stream_write : process(clk,rst,valid) is
  begin
    if rst='1' then
      send_state<=-2;
      ready_o<='0';
      txd<='1';
    elsif clk'event and (clk='1') then
      ready_o <= '0';
      if send_state=-2 then
        ready_o<='1';
        if (ready_o='1') and (valid='1') then
          ready_o<='0';
          send_state<=-1;
          data <= di;
        end if;
      elsif (tick='1') then
        if (send_state=-1) then
          txd<='0';
          send_state<=0;
        elsif send_state<8 then
          txd<=data(send_state);
          send_state<=send_state+1;
        elsif send_state=8 then
          txd<='1';
          send_state<=send_state+1;
        else
          send_state<=-2;
        end if;
      end if;
    end if;
  
  end process;

end Behavioral;
