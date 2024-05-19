library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-----------
entity top is
generic (
c_clkfreq		: integer := 100_000_000;
I2C_BUS_CLK		: integer := 400_000;
DEVICE_ADDR	: STD_LOGIC_VECTOR(6 DOWNTO 0) := "1010010"
);
port (
clk				: in std_logic;
--mode            : in std_logic_vector(1 downto 0); -- drive/reverse/park mode
sens_ena_btn        : in std_logic_vector(0 downto 0); -- enable/disable sensor system
pwr             : in std_logic; -- car on/off
--I2C
SDA 	        : INOUT STD_LOGIC;
SCL 	        : INOUT STD_LOGIC;
SDA_2 	        : INOUT STD_LOGIC;
SCL_2 	        : INOUT STD_LOGIC;
--UART
TX 		        : OUT STD_LOGIC;
rx_i            : in STD_LOGIC;
--7-segment Display
seg     : out std_logic_vector(6 downto 0);
an      : out std_logic_vector(3 downto 0);
--HC_SR04

--Outputs for Leds and Sound
buzzer_output   : out std_logic; -- Determine the frequency of the buzzer sound
LED 	        : OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
);
end top;
-------------------

architecture Behavioral of top is

-------------------
component debouncer
        Generic(
            DEBNC_CLOCKS : integer;
            PORT_WIDTH : integer);
        Port(
            SIGNAL_I : in std_logic_vector(0 downto 0); -- just 1 element, but it's a vector type
            CLK_I : in std_logic;          
            SIGNAL_O : out std_logic_vector(0 downto 0)); -- just 1 element, but it's a vector type
    end component;


component GY_530 IS
generic (
	c_clkfreq		: INTEGER := 100_000_000;
	I2C_BUS_CLK		: INTEGER := 400_000;
	DEVICE_ADDR		: STD_LOGIC_VECTOR(6 DOWNTO 0) := "1010010"
);
port ( 
	CLK 			: IN STD_LOGIC;
	RST_GY 			: IN STD_LOGIC; -- will not be input dependent automatically handled by the program
	SCL 			: INOUT STD_LOGIC;
	SDA 			: INOUT STD_LOGIC;
	INTERRUPT 		: OUT STD_LOGIC;
	TEMP 			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0) -- Sensor transfers 2 byte
);
end component;

component uart_tx is
generic (
c_clkfreq		: integer := 100_000_000;
c_baudrate		: integer := 115_200;
c_stopbit		: integer := 2
);
port (
clk				: in std_logic;
din_i			: in std_logic_vector (7 downto 0);
tx_start_i		: in std_logic;
tx_o			: out std_logic;
tx_done_tick_o	: out std_logic
);
end component;


component uart_rx is
generic (
c_clkfreq		: integer := 100_000_000;
c_baudrate		: integer := 115_200
);
port (
clk				: in std_logic;
rx_i			: in std_logic;
dout_o			: out std_logic_vector (7 downto 0);
rx_done_tick_o	: out std_logic
);
end component;

-- HC_SR04 will be added
component HC_SR04 IS
generic (
c_clkfreq		: integer := 100_000_000
);
port (
clk				: in std_logic 
);	
end component;
-------------------

-------------------
-- UART_TX signals
signal tx_start 	: std_logic := '0';
signal tx_done_tick : std_logic := '0';
signal din 			: std_logic_vector (7 downto 0) := (others => '0');

-- GY_530 signals
signal INTERRUPT 	: std_logic := '0';
signal TEMP		 	: std_logic_vector (12 downto 0) := (others => '0');
signal RST_GY_front       : std_logic := '0'; --initially turned off assuming a distance more than 2 meters
signal RST_GY_back      : std_logic := '0'; --initially turned off assuming a distance more than 2 meters

-- UART_RX signals
signal dout			: std_logic_vector (7 downto 0) := (others => '0');
signal rx_done_tick : std_logic := '0';

-- HCSR04 signals
signal RST_HC_front : std_logic := '0'; --initially turned off assuming power off
signal RST_HC_back  : std_logic := '0'; --initially turned off assuming power of

-- Functionality signals
type states is (Modes,Sensor_en,Sensor_choose,Data_Process);
signal state : states:= Modes;

signal led_intermediate           : std_logic_vector(15 downto 0);
signal buzzer_output_intermediate : std_logic;
signal sevsegval                  : integer range 0 to 3 := 3; -- initially power off
signal sevsegval_tens             : integer range 0 to 10 := 10; -- initially power off
signal sevsegval_ones             : integer range 0 to 10 := 10; -- initially power off
signal sensor_enable              : std_logic; -- indicates enable/disable
signal mode                       : std_logic_vector(1 downto 0):= "00"; -- drive/reverse/park mode


-- Debouncer signals
signal sens_ena_btn_d     : std_logic_vector(0 downto 0); -- to match debouncer instantiation
signal sens_ena_btn_d_d   : std_logic := '0'; 
signal sens_ena_btn_d_re  : std_logic;

 
-------------------

begin
-------------------
GY_530_front : GY_530
GENERIC MAP(
	c_clkfreq		=> c_clkfreq		,
	I2C_BUS_CLK	=> I2C_BUS_CLK	,
	DEVICE_ADDR	=> DEVICE_ADDR	
)
PORT MAP( 
	CLK 		=> CLK 		    ,
	RST_GY 		=> RST_GY_front 		,
	SCL 		=> SCL 		    ,
	SDA 		=> SDA 		    ,
	INTERRUPT 	=> INTERRUPT 	,
	TEMP 		=> TEMP 		
);

GY_530_back : GY_530
GENERIC MAP(
	c_clkfreq		=> c_clkfreq		,
	I2C_BUS_CLK	=> I2C_BUS_CLK	,
	DEVICE_ADDR	=> DEVICE_ADDR	
)
PORT MAP( 
	CLK 		=> CLK 		    ,
	RST_GY 		=> RST_GY_back 		,
	SCL 		=> SCL_2 		    ,
	SDA 		=> SDA_2 	    ,
	INTERRUPT 	=> INTERRUPT 	,
	TEMP 		=> TEMP 		
);

i_uart_tx : uart_tx
generic map (
c_clkfreq		=> c_clkfreq,	
c_baudrate		=> 115_200	,
c_stopbit		=> 2	
)
port map(
clk				=> clk,
din_i			=> din,
tx_start_i		=> tx_start,
tx_o			=> tx,
tx_done_tick_o	=> tx_done_tick
);

i_uart_rx: uart_rx 
generic map(
c_clkfreq		=> c_clkfreq,
c_baudrate		=> 115_200	
)
port map(
clk				=> clk,
rx_i			=> rx_i,
dout_o			=> dout,
rx_done_tick_o	=> rx_done_tick
);

debounce_module: debouncer 
generic map(
DEBNC_CLOCKS => (2**16), -- this number X the clock period (10 ns) makes approx. a 0.655 ms debouncing period
PORT_WIDTH => 1) -- just 1 button
port map(SIGNAL_I => sens_ena_btn, CLK_I => clk, SIGNAL_O => sens_ena_btn_d);


-- HCSR04 front and back components will be added here


-------------------
an <= "0111";

with sevsegval select -- configuration ABCDEFG for .xdc file
        seg <= "0011000" when 0, -- P
               "0111000" when 1, -- F
               "0001000" when 2, -- R 
               "1111111" when others; -- POWER off has value 3 which is in others
        
an <= "1011";

with sevsegval_tens select
        seg <= "1000000" when 0, 
               "1111001" when 1, 
               "0100100" when 2,  
               "1000000" when 3, 
               "1111001" when 4, 
               "0100100" when 5, 
               "1000000" when 6, 
               "1111001" when 7, 
               "0100100" when 8, 
               "1000000" when 9, 
               "1111111" when others; -- POWER off has value 10 which is in others
    
an <= "1101";

with sevsegval_ones select
        seg <= "1000000" when 0, 
               "1111001" when 1, 
               "0100100" when 2,  
               "1000000" when 3, 
               "1111001" when 4, 
               "0100100" when 5,  
               "1000000" when 6, 
               "1111001" when 7, 
               "0100100" when 8,  
               "1000000" when 9, 
               "1111111" when others; -- POWER off has value 10 which is in others

receive_UART:process(CLK) 
begin
if (rising_edge(CLK)) then

if (RX_DONE_TICK = '1') then
	       if( dout = "01010010") then  -- R, reverse mode
	           mode <= "10";
	       elsif ( dout = "01000110") then --F, drive mode
	           mode <= "01";
	       elsif ( dout = "01010000") then -- P , park mode
	           mode <= "00";
	       else 
	           mode <= mode;
	       end if;
	   end if;
end if;

end process;

state_machine:process (CLK) 
begin

if (PWR = '0') then

-- Disables all the sensors
rst_gy_front <= '0';
rst_gy_back <= '0';
rst_hc_front <= '0';
rst_hc_back <= '0';
-- Turns off all the outputs to leds, seven segment and buzzer
led_intermediate <= (others => '0');
buzzer_output_intermediate <= '0';
sevsegval <= 3;  
sevsegval_tens <= 10; 
sevsegval_ones <= 10;  

elsif (rising_edge(CLK)) then


    case (state) is
	
	when Modes =>
	
	       if (mode = "00") then -- P mode
	           sevsegval <= 0;
	           -- no change in state as no sensor is needed in this mode
	       elsif(mode = "10") then -- R mode
	           sevsegval <= 2;
	           state <= Sensor_en; -- next state will be sensor enable/disable
	       elsif(mode = "01") then -- D mode
	           sevsegval <= 1;
	           state <= Sensor_en; -- next state will be sensor enable/disable
	       else 
	           sevsegval <= 0;
	           -- no change in state as no sensor is needed in this mode
	       
	       end if;
	    
	
	when  Sensor_en =>
	        --change the enable flag with the rising edge detection of the button
	        if (sens_ena_btn_d_re = '1') then
	               if(sensor_enable = '1') then
	                   sensor_enable <= '0';
	               else
	                   sensor_enable <= '1';
	               end if;
	         else
	               -- no change in sensor enable flag
             end if;
             
             if (sensor_enable = '1') then
                  state <= Sensor_choose; 
             else
                  state <= Modes; -- no sensor enable go back to the first state            
             end if; 
	
	when Sensor_choose =>
	       
	       if (mode = "01") then
	             if(rst_gy_front = '0' and rst_hc_front = '0') then
	               rst_hc_front <= '1'; -- initial condition 
	               
	             elsif(rst_gy_front = '1' and rst_hc_front = '0') then
	               if (Temp = "1111111111111111") then
	                 -- this will be determined later
	               else 
	                 -- this will be determined later
	               end if;
	             elsif(rst_gy_front = '0' and rst_hc_front = '1') then
	               if (Temp = "1111111111111111") then
	                 -- this will be determined later
	               else 
	                 -- this will be determined later
	               end if;
	               
	             end if;
	             
	             
	       elsif (mode = "10") then
	       
	             if(rst_gy_back = '0' and rst_hc_back = '0') then
	               rst_hc_back <= '1'; -- initial condition 
	             elsif(rst_gy_back = '1' and rst_hc_back = '0') then
	               if (Temp = "1111111111111111") then
	                 -- this will be determined later
	               else 
	                 -- this will be determined later
	               end if;
	             elsif(rst_gy_back = '0' and rst_hc_back = '1') then
	               if (Temp = "1111111111111111") then
	                 -- this will be determined later
	               else 
	                 -- this will be determined later
	               end if;
	               
	             end if;
	       
	       end if;
	       
	       state <= Data_Process;
	       
	      
	
	when Data_Process =>
	   
	   
	   DIN	<= TEMP(7 downto 0);    -- Bu koda göre ilk olarak temp'in high byte'? sonra low byte'? gönderilecek.
                                -- sensörden gelen iki byte verinin TEMP'e at?laca??n? varsayd?m.
	   if (INTERRUPT = '1') then
		  DIN			<= '0' & '0' & '0' & '0' & '0' & '0' & TEMP(9 downto 8);
		  TX_START	<= '1';
	   end if;		

	   if (TX_DONE_TICK = '1') then
		  TX_START	<= '0';
	   end if;

	   state <= Modes; -- go back to the first state for another data transfer
    end case;		
end if;
end process;

buzzer_led_output: process(clk,INTERRUPT) -- bunu data process caseine de koyabiliriz sıkıntı çıkarabilir
begin
-- temp data will be processed by saygıdeğer 
--Ata Bilgin and intermediate buzzer and led outputs will be determined
end process;



-- circuit progressing states and sevent segment with clock tick here
    -- this is the clocked part, the button rising edge is also computed here
    -- see the stackoverflow link at the file header as to why we didn't use rising_edge() for this and manually computed it 
button_detection: process(clk)
begin
    if rising_edge(clk) then
        sens_ena_btn_d_d <= sens_ena_btn_d(0);
    end if;
        sens_ena_btn_d_re <= not sens_ena_btn_d_d and sens_ena_btn_d(0);
        
end process;


led <= led_intermediate; -- power off/on will be displayed on right most LED
buzzer_output <= buzzer_output_intermediate; 

end Behavioral;
