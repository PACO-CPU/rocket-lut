library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity uart_receiver is
	generic(
		CLK_FREQ  : integer := 50000000;
		BAUD_RATE : integer := 9600
	);
	port(
		clk      : in  STD_LOGIC;
		rst      : in  STD_LOGIC;
		rxd      : in  STD_LOGIC;
		valid : out STD_LOGIC;
		do       : out STD_LOGIC_VECTOR (7 downto 0)
	);
end uart_receiver;

architecture Behavioral of uart_receiver is
	type STATE_T is (STATE_IDLE, STATE_RECEIVE);
	signal state : STATE_T;
	signal brg_rst : std_logic;
	signal tick : std_logic;
	signal frame : std_logic_vector(8 downto 0);
	signal index : integer range 0 to 9;
begin

	baud_rate_gen_i : entity work.baud_rate_generator
	generic map (
		CLK_FREQ => CLK_FREQ,
		BAUD_RATE => BAUD_RATE
	)
	port map (
		clk => clk,
		rst => brg_rst,
		tick => tick
	);
	
	do <= frame(7 downto 0);
	brg_rst <= '1' when state = STATE_IDLE else '0';
	
	process(clk, rst)
	begin
		if rst = '1' then
			state <= STATE_IDLE;
			index <= 0;
			frame <= (others => '0');
		elsif rising_edge(clk) then
			valid <= '0';
			case state is
				when STATE_IDLE =>
					if rxd = '0' then
						state <= STATE_RECEIVE;
					end if;
					
				when STATE_RECEIVE =>
					if tick = '1' then
						frame <= rxd & frame(8 downto 1);
						if index = 9 then
							index <= 0;
							state <= STATE_IDLE;
							valid <= '1';
						else
							index <= index + 1;
						end if;
					end if;
			end case;
		end if;
	end process;

end Behavioral;
