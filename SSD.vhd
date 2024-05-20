library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all ;
use IEEE.numeric_std.all;

entity SSD is
    Port (  clk : in STD_LOGIC; -- 1 KHz Clock
            Number : in STD_LOGIC_VECTOR ( 9 downto 0); -- binary number input
            Segment : out STD_LOGIC_VECTOR ( 6 downto 0); -- SSD output
            an : out STD_LOGIC_VECTOR ( 3 downto 0); -- anode output
            mode: in STD_LOGIC_VECTOR ( 2 downto 0)
          );
end SSD;

architecture Behavioral of SSD is
    
    SIGNAL numb : INTEGER;
    SIGNAL First_Digit, Second_Digit, Third_Digit:STD_LOGIC_VECTOR ( 3 downto 0);
    SHARED VARIABLE int : INTEGER := 0;
    SIGNAL temp : STD_LOGIC_VECTOR ( 3 downto 0) := "0000";
    SIGNAL anode : STD_LOGIC_VECTOR ( 3 downto 0) := "1110";
    
begin
    
    numb <= to_integer(unsigned( Number));
    First_Digit <= std_logic_vector(to_unsigned( (numb mod 10), 4));
    Second_Digit <= std_logic_vector(to_unsigned( ((numb/10) mod 10), 4));
    Third_Digit <= std_logic_vector(to_unsigned( (numb/100), 4));
    
    PROCESS (clk)
    BEGIN
        if ( clk'event and clk = '1') then
            if ( int = 3) then
                if (mode = "00") then
                    temp <= "0000";  -- SHOW 000P in P mode
                else
                    temp <= Third_Digit;  -- otherwise
                    an <= "1011";
                    int := 0;
                end if;
                
            elsif ( int = 2) then
                if (mode = "00") then
                    temp <= "0000";  -- SHOW 000P in P mode
                else
                    temp <= Second_Digit;  -- otherwise
                    an <= "1101";
                    int := int + 1;
                end if;
                
            elsif ( int = 1) then
                if (mode = "00") then
                    temp <= "0000";  -- SHOW 000P in P mode
                else 
                    temp <= First_Digit; -- otherwise
                    an <= "1110";
                    int := int + 1;
                end if;
                
            elsif ( int = 0) then
                an <= "0111";
                if( mode = "01" ) then
                    temp <= "1010"; -- 10 is assigned to indicate D mode
                elsif ( mode = "10" ) then
                    temp <= "1011"; -- 11 is assigned to indicate R mode
                elsif ( mode = "00" ) then
                    temp <= "1100"; -- 12 is assigned to indicate P mode
                end if;
                
            end if;
        end if;
    END PROCESS;
    
    
    PROCESS (temp)
    BEGIN
        if ( temp = "0000") then
--            Segment <=  "1111110"; -- 0 -- 126
            Segment <=  "1000000"; -- 0 -- 
        elsif  ( temp = "0001") then
--            Segment <=  "0110000"; -- 1 -- 48
            Segment <=  "1111001"; -- 1 -- 
        elsif  ( temp = "0010") then
--            Segment <=  "1101101"; -- 2 -- 109
            Segment <=  "0100100"; -- 2 -- 
        elsif  ( temp = "0011") then
--            Segment <=  "1111001"; -- 3 -- 121
            Segment <=  "0110000"; -- 3 -- 
        elsif  ( temp = "0100") then
--            Segment <=  "0110011"; -- 4 -- 51
            Segment <=  "0011001"; -- 4 -- 
        elsif  ( temp = "0101") then
--            Segment <=  "1011011"; -- 5 -- 91
            Segment <=  "0010010"; -- 5 -- 
        elsif  ( temp = "0110") then
--            Segment <=  "1011111"; -- 6 -- 95
            Segment <=  "0000010"; -- 6 -- 
        elsif  ( temp = "0111") then
--            Segment <=  "1110000"; -- 7 -- 112
            Segment <=  "1111000"; -- 7 -- 
        elsif  ( temp = "1000") then
--            Segment <=  "1111111"; -- 8 -- 127
            Segment <=  "0000000"; -- 8 -- 
        elsif  ( temp = "1001") then
--            Segment <=  "1111011"; -- 9 -- 123
            Segment <=  "0010000"; -- 9 -- 
        elsif ( temp = "1010") then
        --            Segment <=  "0111101";
            Segment <=  "0100001"; --  D mode
        elsif ( temp = "1011") then
        --            Segment <=  "0000101";
            Segment <=  "0101111"; --  R mode
        elsif ( temp = "1100") then
        --            Segment <=  "1100111";
            Segment <=  "0001100"; --  P mode    
        end if;
    END PROCESS;
    
end Behavioral;