----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 	Mehmet Burak AYKENAR
-- 
-- Create Date: 07/02/2019 07:50:36 AM
-- Design Name: 
-- Module Name: GY530 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

ENTITY GY530 IS
GENERIC (
	CLKFREQ		: INTEGER := 100_000_000;
	I2C_BUS_CLK	: INTEGER := 400_000;
	DEVICE_ADDR	: STD_LOGIC_VECTOR(6 DOWNTO 0) := "1010010" -- 0x52 device address

);
PORT ( 
	CLK 		: IN STD_LOGIC;
	RST_GY 		: IN STD_LOGIC;
	SCL 		: INOUT STD_LOGIC;
	SDA 		: INOUT STD_LOGIC;
	INTERRUPT 	: OUT STD_LOGIC;
	TEMP 		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
);
END GY530;

architecture Behavioral of GY530 is

COMPONENT I2C_MASTER IS
  GENERIC(
    INPUT_CLK : INTEGER := 25_000_000; --INPUT CLOCK SPEED FROM USER LOGIC IN HZ
    BUS_CLK   : INTEGER := 400_000);   --SPEED THE I2C BUS (SCL) WILL RUN AT IN HZ
  PORT(
    CLK       : IN     STD_LOGIC;                    --SYSTEM CLOCK
    RESET_N   : IN     STD_LOGIC;                    --ACTIVE LOW RESET
    ENA       : IN     STD_LOGIC;                    --LATCH IN COMMAND
    ADDR      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --ADDRESS OF TARGET SLAVE
    RW        : IN     STD_LOGIC;                    --'0' IS WRITE, '1' IS READ
    DATA_WR   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --DATA TO WRITE TO SLAVE
    BUSY      : OUT    STD_LOGIC;                    --INDICATES TRANSACTION IN PROGRESS
    DATA_RD   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --DATA READ FROM SLAVE
    ACK_ERROR : BUFFER STD_LOGIC;                    --FLAG IF IMPROPER ACKNOWLEDGE FROM SLAVE
    SDA       : INOUT  STD_LOGIC;                    --SERIAL DATA OUTPUT OF I2C BUS
    SCL       : INOUT  STD_LOGIC);                   --SERIAL CLOCK OUTPUT OF I2C BUS
END COMPONENT;

--------------------------------------------------------------------------------------------------------------------------------
-- SIGNALS AND CONSTANTS --
-- i2c_master signals
-- signal rst 		: std_logic := '0';		-- resets the i2c_master when '0'
signal ena			: std_logic := '0';
-- constant addr   	: std_logic_vector (6 downto 0) := "1010010";
signal rw       	: std_logic := '0';
signal data_wr  	: std_logic_vector (7 downto 0) := (others => '0');
signal busy     	: std_logic := '0';
signal busyPrev     : std_logic := '0';
signal busyCntr		: integer range 0 to 255 := 0;
signal data_rd  	: std_logic_vector (7 downto 0) := (others => '0');
signal ack_error	: std_logic := '0';  

signal enable	: std_logic := '0';
signal waitEn	: std_logic := '0';
signal cntr		: integer range 0 to 255 := 0;

-- state machine
type states is (IDLE_S, ACQUIRE_S);
signal state : states := IDLE_S;

-- SIGNALS
constant cntr200msLim : integer := clkFreq/4;			-- 5 Hz
--constant cntr200msLim : integer := clkFreq/1000;			-- for test
signal cntr200ms : integer range 0 to cntr200msLim-1 := 0;
signal cntr200msEn : std_logic := '0';
signal cntr200msTick : std_logic := '0';

begin
--------------------------------------------------------------------------------------------------------------------------------
-- COMPONENT INSTANTIATIONS --
i2c_master_inst	: i2c_master 
GENERIC MAP (
input_clk	=> CLKFREQ,
bus_clk  	=> I2C_BUS_CLK
)
PORT MAP (
clk      	=> clk,
reset_n  	=> RST_N,
ena      	=> ena,
addr     	=> DEVICE_ADDR,
rw       	=> rw,
data_wr     => data_wr,
busy        => busy,
data_rd     => data_rd,
ack_error   => ack_error,
sda         => SDA,
scl         => SCL
);

cntr250msEn	<= '1';

--------------------------------------------------------------------------------------------------------------------------------
-- MAIN STATE MACHINE --
MAIN : process (clk)
begin
if (rising_edge(clk)) then

	case (state) is		

		-- IDLE durumunda slave'e register adres icin write command gonderiliyor
		-- ilk guc acilip reset kalktiginda 200 ms bekleniliyor
		-- bir daha bu 200 ms reset olmadikca beklenmiyor	
		when IDLE_S =>
		
			busyPrev	<= busy;
			
			if (busyPrev = '0' and busy = '1') then
				busyCntr <= busyCntr + 1;
			end if;				
		
			INTERRUPT	<= '0';					
			
			-- datasheet'te neden 20	0 ms beklemem gerektigi yaziyor
			if (RST_N = '1') then
				if (cntr200msTick = '1') then
					enable	<= '1';
				end if;	
			else
				enable <= '0';
			end if;
			
			if (enable = '1') then
			
				if (busyCntr = 0) then		-- first byte write
					ena 	<= '1';
					rw		<= '0';		-- write
					data_wr	<= x"C0";	-- temperature MSB
				elsif (busyCntr = 1) then
					ena 	<= '0';
					if (busy = '0') then
						waitEn		<= '1';
						busyCntr	<= 0;				
						enable		<= '0';
					end if;						
				end if;						
				
			end if;
			
			-- wait a little bit - not so critical
			-- bu aslinda kritik, datasheette STOP sonrasi START condition icin min bekleme zamani olarak 1.3 us denilmis
			-- burada beklenecek sure parametrik olsa daha iyi olur, CLKFREQ parametresi ile ifade edilmeli
			
			if (waitEn = '1') then
				if (cntr = 255) then
					state		<= ACQUIRE_S;
					cntr		<= 0;
					waitEn		<= '0';
				else
					cntr 	<= cntr + 1;
				end if;
			end if;
			
		when ACQUIRE_S =>
		
		
			busyPrev	<= busy;
			if (busyPrev = '0' and busy = '1') then
				busyCntr <= busyCntr + 1;
			end if;		
		
			if (busyCntr = 0) then		
				ena 	<= '1';
				rw		<= '1';		-- read
				data_wr	<= x"C0";	
			elsif (busyCntr = 1) then	-- read starts
				if (busy = '0') then
					TEMP(15 downto 8)	<= data_rd;
				end if;					
				rw 		<= '1';
			elsif (busyCntr = 2) then	-- data read
				ena	<= '0';
				if (busy = '0') then
					TEMP(7 downto 0)	<= data_rd;
					state				<= IDLE_S;
					busyCntr			<= 0;
					INTERRUPT			<= '1';
				end if;						
			end if;			

	end case;
	
end if;
end process;


CNTR250MS_P : process (clk)
begin
if (rising_edge(CLK)) then
	
	if (cntr200msEn = '1') then
		if (cntr200ms = cntr200msLim - 1) then
			cntr200msTick	<= '1';
			cntr200ms 		<= 0;
		else
			cntr200msTick	<= '0';
			cntr200ms 		<= cntr200ms + 1;
		end if;
	else
		cntr200msTick	<= '0';
		cntr200ms 		<= 0;
	end if;
	
end if;
end process;


end Behavioral;
