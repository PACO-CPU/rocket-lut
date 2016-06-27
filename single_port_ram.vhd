library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;

library paco_lut;

entity single_port_ram is
  generic (
    DATA_WIDTH : integer := 32;
    ADDR_WIDTH  : integer := 8
  );
  port(
    clk : in std_logic; 
    port1_addr   : in  std_logic_vector(0 to ADDR_WIDTH-1); 
    port1_data_w : in  std_logic_vector(0 to DATA_WIDTH-1); 
    port1_data_r : out std_logic_vector(0 to DATA_WIDTH-1); 
    port1_we     : in  std_logic 
  );
end entity;

architecture implementation of dual_port_ram is
  type ram_t is
    array(0 to 2**ADDR_WIDTH-1)
    of std_logic_vector(0 to DATA_WIDTH-1);
  shared variable ram: ram_t;
  
begin 
  
  port1_ctrl : process(clk) is
  begin
    if rising_edge(clk) then
      if port1_we='1' then
        ram(conv_integer(unsigned(port1_addr))) := port1_data_w;
      else
        port1_data_r <= ram(conv_integer(unsigned(port1_addr)));
      end if;
    end if;
  end process;
  
end architecture;
