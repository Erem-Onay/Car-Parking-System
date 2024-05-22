library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

-----------
entity top2 is
generic (
c_clkfreq		: integer := 100_000_000;
I2C_BUS_CLK		: integer := 400_000;
DEVICE_ADDR	: STD_LOGIC_VECTOR(6 DOWNTO 0) := "1010010"
);
port ( 
clk				: in std_logic;
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
end top2;
-------------------

architecture Behavioral of top2 is

-------------------
component SSD is
    Port (  clk : in STD_LOGIC; -- 1 KHz Clock
            Number : in STD_LOGIC_VECTOR ( 12 downto 0); -- binary number input
            Segment : out STD_LOGIC_VECTOR ( 6 downto 0); -- SSD output
            an : out STD_LOGIC_VECTOR ( 3 downto 0); -- anode output
            mode: in STD_LOGIC_VECTOR ( 1 downto 0)
          );
end component;

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
	RST_N 			: IN STD_LOGIC; -- will not be input dependent automatically handled by the program
	SCL 			: INOUT STD_LOGIC;
	SDA 			: INOUT STD_LOGIC;
	INTERRUPT 		: OUT STD_LOGIC;
	TEMP 			: OUT STD_LOGIC_VECTOR (12 DOWNTO 0) -- Sensor transfers 2 byte
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
signal TEMP1		 	: std_logic_vector (12 downto 0) := (others => '0');
signal TEMP2		 	: std_logic_vector (12 downto 0) := (others => '0');
signal RST_GY_front       : std_logic := '0'; --initially turned off assuming a distance more than 2 meters
signal RST_GY_back      : std_logic := '0'; --initially turned off assuming a distance more than 2 meters

-- UART_RX signals
signal dout			: std_logic_vector (7 downto 0) := (others => '0');
signal rx_done_tick : std_logic := '0';

-- HCSR04 signals
signal RST_HC_front : std_logic := '0'; --initially turned off assuming power off
signal RST_HC_back  : std_logic := '0'; --initially turned off assuming power of

-- Functionality signals
type states is (Sensor_en, Sensor_choose, dis_control, Data_Process);
signal state : states:= Sensor_en;

signal led_intermediate           : std_logic_vector(15 downto 0);
signal buzzer_output_intermediate : std_logic;


signal mode                       : std_logic_vector(1 downto 0):= "00"; -- drive/reverse/park mode

signal TX_done : std_logic;

-- Debouncer signals
signal sens_ena_btn_d     : std_logic_vector(0 downto 0); -- to match debouncer instantiation
signal sens_ena_btn_d_d   : std_logic := '0'; 
signal sens_ena_btn_d_re  : std_logic;

 type tState is (onn, off); -- to show that the enumerated states can be arbitrary names 
    signal state_t0, state_t1: tState; 

signal counter : INTEGER := 0; 
signal clk_divider : INTEGER := 0; -- will be used for buzzer
constant base_freq : INTEGER := 1000;     -- Base frequency for buzzer in Hz


signal TEMP		 	: std_logic_vector (12 downto 0) := (others => '0');
-------------------


begin
-------------------
seven_seg : SSD 
PORT MAP( 
	CLK 		=> CLK 		    ,
    mode        => mode         ,
    number      => temp         ,	
    an          => an           ,
    segment     => seg
);


GY_530_front : GY_530
GENERIC MAP(
	c_clkfreq		=> c_clkfreq		,
	I2C_BUS_CLK	=> I2C_BUS_CLK	,
	DEVICE_ADDR	=> DEVICE_ADDR	
)
PORT MAP( 
	CLK 		=> CLK 		    ,
	RST_N 		=> RST_GY_front 		,
	SCL 		=> SCL 		    ,
	SDA 		=> SDA 		    ,
	INTERRUPT 	=> INTERRUPT 	,
	TEMP 		=> TEMP1 		
);

GY_530_back : GY_530
GENERIC MAP(
	c_clkfreq		=> c_clkfreq		,
	I2C_BUS_CLK	=> I2C_BUS_CLK	,
	DEVICE_ADDR	=> DEVICE_ADDR	
)
PORT MAP( 
	CLK 		=> CLK 		    ,
	RST_N 		=> RST_GY_back 		,
	SCL 		=> SCL_2 		    ,
	SDA 		=> SDA_2 	    ,
	INTERRUPT 	=> INTERRUPT 	,
	TEMP 		=> TEMP2		
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
receive_UART:process(CLK) 
begin
if (rising_edge(CLK)) then

if (RX_DONE_TICK = '1') then
	       if( dout = "01010010") then  -- R, reverse mode
	           mode <= "10";
	       elsif ( dout = "01000110") then -- F, drive mode
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
    
    led_intermediate(15 downto 0)	<= "0000000000000000";
    
---- Disables all the sensors
--rst_gy_front <= '0';  -- no need to use these signals 
--rst_gy_back <= '0';
--rst_hc_front <= '0';
--rst_hc_back <= '0';

-- Turns off all the outputs to leds, seven segment and buzzer
led_intermediate <= (others => '0');
buzzer_output_intermediate <= '0';
 

elsif (rising_edge(CLK)) then


    case (state) is
	    
	
	when  Sensor_en =>
	        if (state_t0 = off) then
	                   state <= Sensor_en;  
	        elsif (state_t1 = onn) then
	                   state <= Sensor_choose;
	        end if;
	        
	        TX_done <= '0';
	
	when Sensor_choose =>
	       
	       if ( mode = "00") then  -- button does not work in the Park mode
	           state <= Sensor_en;
	           	        
	       -- assume distance greater than 2m and start using hc
	       -- control the data in the next stage
	       
	       elsif (mode = "01") then -- drive mode
	               -- TEMP <= TEMP3; -- hc front
	               state <= dis_control;
	             
	       elsif (mode = "10") then  -- reverse mode
	               -- TEMP <= TEMP4; -- hc back
	               state <= dis_control;
	            
	       end if;	      
	       
	       
	when dis_control =>     
	       
	       -- check whether distance is smaller than 200 cm, if it is
	       -- use other TEMP 
	       
	       if (mode = "01") then -- drive mode
	               if (to_integer(unsigned(TEMP)) < 200) then -- assumed temp in cm
	                    TEMP <= TEMP1;
	               else 
	                    TEMP <= TEMP;
	               end if;    
	                 
	
	       elsif (mode = "10") then  -- reverse mode
	               if (to_integer(unsigned(TEMP)) < 200) then -- assumed temp in cm
	                    TEMP <= TEMP2;
	               else 
	                    TEMP <= TEMP;
	               end if;    
	       end if;
	 
	       state <= Data_Process;
	    	     
	       
	when Data_Process =>
	   
	   
	   DIN	<= TEMP(7 downto 0);    -- Bu koda göre ilk olarak temp'in high byte'? sonra low byte'? gönderilecek.
                                -- sensörden gelen iki byte verinin TEMP'e at?laca??n? varsayd?m.
	   if (INTERRUPT = '1') then
		  DIN			<= '0' & '0' & '0' & '0' & '0' & '0' & TEMP(9 downto 8);
		  TX_START	<= '1';  
		  state <= Data_Process;  -- in the first clock
	   end if;		

	   if (TX_DONE_TICK = '1') then
		  TX_START	<= '0';
		  state <= Sensor_en; -- in the second clock
		  TX_done	<= '1'; -- ??
	   end if;
        
       -- IKI BYTELIK VERININ GONDERILMESI ICIN 2 CLOCK BEKLENMESI GEREKIR GIBI
       -- DURUYOR, IKI CLOCK KERE GIRECEK SEKILDE AYARLADIM
        
    end case;		
end if;
end process;

------------- 
buzzer_led_output: process(TX_done) 
begin   -- 16 LEDs is going to be used for distance 
        if (to_integer(unsigned(TEMP)) < 25) then
               led_intermediate(15 downto 0)	<= "1111111111111111";
               clk_divider <= c_clkfreq / (base_freq * 150);
        elsif (to_integer(unsigned(TEMP)) < 50) then
               led_intermediate(15 downto 0)	<= "0111111111111111";
               clk_divider <= c_clkfreq / (base_freq * 140);
        elsif (to_integer(unsigned(TEMP)) < 75) then
               led_intermediate(15 downto 0)	<= "0011111111111111";
               clk_divider <= c_clkfreq / (base_freq * 130);
        elsif (to_integer(unsigned(TEMP)) < 100) then
               led_intermediate(15 downto 0)	<= "0001111111111111";
               clk_divider <= c_clkfreq / (base_freq * 120);
        elsif (to_integer(unsigned(TEMP)) < 125) then
               led_intermediate(15 downto 0)	<= "0000111111111111";
               clk_divider <= c_clkfreq / (base_freq * 110);
        elsif (to_integer(unsigned(TEMP)) < 150) then
               led_intermediate(15 downto 0)	<= "0000011111111111";
               clk_divider <= c_clkfreq / (base_freq * 100);
        elsif (to_integer(unsigned(TEMP)) < 175) then
               led_intermediate(15 downto 0)	<= "0000001111111111";
               clk_divider <= c_clkfreq / (base_freq * 90);
        elsif (to_integer(unsigned(TEMP)) < 200) then
               led_intermediate(15 downto 0)	<= "0000000111111111";
               clk_divider <= c_clkfreq / (base_freq * 80);
        elsif (to_integer(unsigned(TEMP)) < 225) then
               led_intermediate(15 downto 0)	<= "0000000011111111";
               clk_divider <= c_clkfreq / (base_freq * 70);
        elsif (to_integer(unsigned(TEMP)) < 250) then
               led_intermediate(15 downto 0)	<= "0000000001111111";
               clk_divider <= c_clkfreq / (base_freq * 60);
        elsif (to_integer(unsigned(TEMP)) < 275) then
               led_intermediate(15 downto 0)	<= "0000000000111111";
               clk_divider <= c_clkfreq / (base_freq * 50);
        elsif (to_integer(unsigned(TEMP)) < 300) then
               led_intermediate(15 downto 0)	<= "0000000000011111";
               clk_divider <= c_clkfreq / (base_freq * 40);
        elsif (to_integer(unsigned(TEMP)) < 325) then
               led_intermediate(15 downto 0)	<= "0000000000001111";
               clk_divider <= c_clkfreq / (base_freq * 30);
        elsif (to_integer(unsigned(TEMP)) < 350) then
               led_intermediate(15 downto 0)	<= "0000000000000111";
               clk_divider <= c_clkfreq / (base_freq * 20);
        elsif (to_integer(unsigned(TEMP)) < 375) then
               led_intermediate(15 downto 0)	<= "0000000000000011";
               clk_divider <= c_clkfreq / (base_freq * 10);
        else 
               led_intermediate(15 downto 0)	<= "0000000000000001";
               clk_divider <= c_clkfreq / (base_freq * 1);
        end if;                      

-- temp data will be processed by sayg?de?er 
--Ata Bilgin and intermediate buzzer and led outputs will be determined
end process;
------------- 

------------- 
buzzer_loop:  process(clk)
begin
    if (rising_edge(clk)) then
    
        if mode = "00" then  -- in P mode, buzzer will be off 
            buzzer_output_intermediate <= '0';
        
        else 
            if counter >= clk_divider then
                counter <= 0;
                buzzer_output_intermediate <= not buzzer_output_intermediate;
            else
                counter <= counter + 1;
            end if;
         end if;
     end if;
    end process;
-------------         



-------------  debouncer part, inspired from lab2
state_machine2: process(state_t0, sens_ena_btn_d, clk)
begin
        case state_t0 is
            when onn   => if sens_ena_btn_d_re = '1' then 
                                state_t1 <= off;
                          else 
                                state_t1 <= onn;
                          end if;
            when off   => if sens_ena_btn_d_re = '1' then 
                                state_t1 <= onn;                
                          else 
                                state_t1 <= off;
                          end if;
        end case;   
    end process;
    
button_detection: process(clk)
begin
    if rising_edge(clk) then
        sens_ena_btn_d_d <= sens_ena_btn_d(0);
        
        state_t0 <= state_t1;
        
    end if;
        sens_ena_btn_d_re <= not sens_ena_btn_d_d and sens_ena_btn_d(0);
        
end process;
------------- 

led <= led_intermediate; -- power off/on will be displayed on right most LED
buzzer_output <= buzzer_output_intermediate; 

end Behavioral;


