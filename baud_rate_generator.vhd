library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--! @brief Simple tick generator for use in UART transceivers.
--! @details This component takes a clock and reset signal and outputs a
--! tick signal which is set to high for one clock cycle periodically.
--! The period is defined via the generics CLK_FREQ and BAUD_RATE: A tick is
--! generated every floor(CLK_FREQ/BAUD_RATE) clock cycles.
--! The tick rises with clk and falls with the next rise of clk. It is kept
--! low asynchronously while rst is set high.
entity baud_rate_generator is
	generic(
		CLK_FREQ  : integer := 50000000;
		BAUD_RATE : integer := 9600
	);
	port(
		clk  : in  STD_LOGIC;
		rst  : in  STD_LOGIC;
		tick : out  STD_LOGIC
	);
end baud_rate_generator;

architecture implementation of baud_rate_generator is
	constant TICKS_PER_BIT : integer := CLK_FREQ/BAUD_RATE;
	signal counter : integer range 0 to TICKS_PER_BIT-1;
begin

	process (clk, rst)
	begin
		if rst = '1' then
			counter <= TICKS_PER_BIT/2;
			tick <= '0';
		elsif clk'event and clk = '1' then
			if counter = TICKS_PER_BIT-1 then
				counter <= 0;
				tick <= '1';
			else
				counter <= counter + 1;
				tick <= '0';
			end if;
		end if;
	end process;

end architecture;

