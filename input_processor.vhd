library ieee;
use ieee.std_logic_1164.all;

library paco_lut;
use paco_lut.lut_package.all;

entity shifter is
  generic (
    W : integer := 32
  );
  port (
    data_i : in std_logic_vector(W-1 downto 0);
    data_o : out std_logic_vector(W-1 downto 0);
    shamt_i : in std_logic_vector(7 downto 0)
  );
end entity;

architecture implementation of shifter is
  signal de : std_logic_vector(W+63 downto 0);
begin 
  
  de(W+63 downto W) <= (others => '0');
  de(W-1 downto 0) <= data_i;
  
  data_o <=
    de(W+(-1) downto 0) when shamt_i=x"00" else 
    de(W+(0) downto 1) when shamt_i=x"01" else 
    de(W+(1) downto 2) when shamt_i=x"02" else 
    de(W+(2) downto 3) when shamt_i=x"03" else 
    de(W+(3) downto 4) when shamt_i=x"04" else 
    de(W+(4) downto 5) when shamt_i=x"05" else 
    de(W+(5) downto 6) when shamt_i=x"06" else 
    de(W+(6) downto 7) when shamt_i=x"07" else 
    de(W+(7) downto 8) when shamt_i=x"08" else 
    de(W+(8) downto 9) when shamt_i=x"09" else 
    de(W+(9) downto 10) when shamt_i=x"0a" else 
    de(W+(10) downto 11) when shamt_i=x"0b" else 
    de(W+(11) downto 12) when shamt_i=x"0c" else 
    de(W+(12) downto 13) when shamt_i=x"0d" else 
    de(W+(13) downto 14) when shamt_i=x"0e" else 
    de(W+(14) downto 15) when shamt_i=x"0f" else 
    de(W+(15) downto 16) when shamt_i=x"10" else 
    de(W+(16) downto 17) when shamt_i=x"11" else 
    de(W+(17) downto 18) when shamt_i=x"12" else 
    de(W+(18) downto 19) when shamt_i=x"13" else 
    de(W+(19) downto 20) when shamt_i=x"14" else 
    de(W+(20) downto 21) when shamt_i=x"15" else 
    de(W+(21) downto 22) when shamt_i=x"16" else 
    de(W+(22) downto 23) when shamt_i=x"17" else 
    de(W+(23) downto 24) when shamt_i=x"18" else 
    de(W+(24) downto 25) when shamt_i=x"19" else 
    de(W+(25) downto 26) when shamt_i=x"1a" else 
    de(W+(26) downto 27) when shamt_i=x"1b" else 
    de(W+(27) downto 28) when shamt_i=x"1c" else 
    de(W+(28) downto 29) when shamt_i=x"1d" else 
    de(W+(29) downto 30) when shamt_i=x"1e" else 
    de(W+(30) downto 31) when shamt_i=x"1f" else 
    de(W+(31) downto 32) when shamt_i=x"20" else 
    de(W+(32) downto 33) when shamt_i=x"21" else 
    de(W+(33) downto 34) when shamt_i=x"22" else 
    de(W+(34) downto 35) when shamt_i=x"23" else 
    de(W+(35) downto 36) when shamt_i=x"24" else 
    de(W+(36) downto 37) when shamt_i=x"25" else 
    de(W+(37) downto 38) when shamt_i=x"26" else 
    de(W+(38) downto 39) when shamt_i=x"27" else 
    de(W+(39) downto 40) when shamt_i=x"28" else 
    de(W+(40) downto 41) when shamt_i=x"29" else 
    de(W+(41) downto 42) when shamt_i=x"2a" else 
    de(W+(42) downto 43) when shamt_i=x"2b" else 
    de(W+(43) downto 44) when shamt_i=x"2c" else 
    de(W+(44) downto 45) when shamt_i=x"2d" else 
    de(W+(45) downto 46) when shamt_i=x"2e" else 
    de(W+(46) downto 47) when shamt_i=x"2f" else 
    de(W+(47) downto 48) when shamt_i=x"30" else 
    de(W+(48) downto 49) when shamt_i=x"31" else 
    de(W+(49) downto 50) when shamt_i=x"32" else 
    de(W+(50) downto 51) when shamt_i=x"33" else 
    de(W+(51) downto 52) when shamt_i=x"34" else 
    de(W+(52) downto 53) when shamt_i=x"35" else 
    de(W+(53) downto 54) when shamt_i=x"36" else 
    de(W+(54) downto 55) when shamt_i=x"37" else 
    de(W+(55) downto 56) when shamt_i=x"38" else 
    de(W+(56) downto 57) when shamt_i=x"39" else 
    de(W+(57) downto 58) when shamt_i=x"3a" else 
    de(W+(58) downto 59) when shamt_i=x"3b" else 
    de(W+(59) downto 60) when shamt_i=x"3c" else 
    de(W+(60) downto 61) when shamt_i=x"3d" else 
    de(W+(61) downto 62) when shamt_i=x"3e" else 
    de(W+(62) downto 63) when shamt_i=x"3f" else 
    de(W+(63) downto 64) when shamt_i=x"40" else
    (others => '0');

end;

library ieee;
use ieee.std_logic_1164.all;

library paco_lut;
use paco_lut.lut_package.all;

entity input_processor is
  port (
    clk : in std_logic;
    rst : in std_logic;
    
    cfg_i : in  cfg_word_t;
    cfg_o : out cfg_word_t;

    pipeline_i : in p_input_t;
    pipeline_o : out p_pla_t

  );
end entity;

architecture implementation of input_processor is
  constant C_EXTENDED_WIDTH : integer := C_WORD_SIZE+C_INTERPOLATION_BITS;

  signal cfg_shift_amount : cfg_word_t;
  signal input_shifted : std_logic_vector(C_EXTENDED_WIDTH-1 downto 0);
begin
  cfg_o.valid <= cfg_o.valid;

  shft: entity work.shifter generic map (
    W => C_EXTENDED_WIDTH
  ) port map (
    data_i(C_EXTENDED_WIDTH-1 downto C_INTERPOLATION_BITS) => pipeline_i.data,
    data_i(C_INTERPOLATION_BITS-1 downto 0) => (others => '0'),
    data_o => input_shifted,
    shamt_i => cfg_shift_amount.d(7 downto 0)
  );

  process (clk) is 
    variable extended_input: 
      std_logic_vector(
        C_WORD_SIZE+C_SELECTOR_BITS+C_INTERPOLATION_BITS-1 downto 0);
  begin
    if rising_edge(clk) then
      -- daisy-chain our one configuration word
      if cfg_i.valid='1' then
        cfg_shift_amount.d <= cfg_i.d;
        cfg_o.d <= cfg_shift_amount.d;
      end if;
      
      
      -- extend the input word with enough zeroes to the left and right so that
      -- we always have enough bits to extract an interpolator and a selector.
      extended_input := (others => '0');
      extended_input(
        C_WORD_SIZE+C_INTERPOLATION_BITS-1 downto C_INTERPOLATION_BITS) :=
        pipeline_i.data;
      
      pipeline_o.valid <= pipeline_i.valid;
      pipeline_o.interpolator <= input_shifted(C_INTERPOLATION_BITS-1 downto 0);
      pipeline_o.selector <= 
        input_shifted(
          C_INTERPOLATION_BITS+C_SELECTOR_BITS-1 downto C_INTERPOLATION_BITS);
     
      if rst='1' then
        pipeline_o.valid <= '0';
      end if;
    end if;
  end process;
  


end architecture;
