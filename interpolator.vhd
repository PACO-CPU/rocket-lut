library ieee;
use ieee.std_logic_1164.all;

library paco_lut;
use paco_lut.lut_package.all;

entity interpolator is
  port (
    clk : in std_logic;
    rst : in std_logic;
    
    cfg_i : in  cfg_word_t;
    cfg_o : out cfg_word_t;

    pipeline_i : in p_interpolator_t;
    pipeline_o : out p_output_t

  );
end entity;

architecture implementation of interpolator is
 
  type p_delay_t is array(0 to C_INTERPOLATOR_DELAY) of p_output_t;
  signal p_delay : p_delay_t;
begin
  cfg_o <= cfg_i; -- no configuration words

  process (clk) is
    variable i: integer;
  begin
    if rising_edge(clk) then
      
      p_delay(0).valid <= pipeline_i.valid;

      p_delay(0).data <= (others => '0'); -- todo: perform multiply, add 

      for i in 1 to C_INTERPOLATOR_DELAY loop
        p_delay(i) <= p_delay(i-1);
      end loop;
      
      if rst='1' then
        for i in 1 to C_INTERPOLATOR_DELAY loop
          p_delay(i).valid <= '0';
        end loop;
      end if;

    end if;
  end process;
  
  pipeline_o <= p_delay(C_INTERPOLATOR_DELAY);

end architecture;
