library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity UltraSonicSensor is
  Port ( Clock : in STD_LOGIC; -- 100 MHz
         Echo  : in STD_LOGIC; -- return signal from the sensor
         Trig  : out STD_LOGIC; -- Trigger for the sensor
         Distance   : out STD_LOGIC_VECTOR (9 downto 0) -- distance in binary (15-bit)
         );
end UltraSonicSensor;   

architecture Behavioral of UltraSonicSensor is
-----clockdivider------
    SIGNAL syncM : STD_LOGIC := '1';
    SIGNAL int1, int2 : INTEGER := 0;
-----Triggen-----------
    SIGNAL Start : STD_LOGIC := '1';
-----DistanceCalc------
    SIGNAL Dist : STD_LOGIC_VECTOR (14 downto 0); -- distance in decimal

begin
-----clockdivider------
    process ( Clock)
    begin
        --frequency = 1 MHz
        if ( rising_edge( Clock)) then
            if ( int1 < 49) then
                int1 <= int1 + 1;
            else
                int1 <= 0;
                syncM <= NOT syncM;
            end if;
        end if;   

    end process;
-----Triggen-----------
    process (Echo, SyncM)
        VARIABLE int : INTEGER := 0;
    begin
        
        if ( SyncM'event and SyncM = '1' and Echo = '0') then
            if (int = 10 ) then
                start <= '0';
                int := 0;
                Trig <= '0';
            elsif (int < 10 and start = '1') then
                int := int + 1;
                Trig <= '1';
            end if;
        end if; -- elsif
        if ( Echo = '1') then -- elsif
            int := 0;
            Trig <= '0';
            start <= '1';
        end if;
        
    end process;
---DistanceCalc----
    PROCESS ( Echo, SyncM)
    begin
        if ( SyncM'event and SyncM = '1') then
            if ( Echo = '1') then
                Dist <= Dist + 1;
            else
                if ( Echo = '0') then
                    if ( Dist = not "000000000000000") then
                    Distance <= std_logic_vector(to_unsigned(to_integer(unsigned( Dist ) / 58), 10)); -- divide total time by 58 to obtain distance in cm
                else
                    Dist <= "000000000000000";
                end if;
            end if;
        end if;
            
      end if;
    end process;


end Behavioral;
