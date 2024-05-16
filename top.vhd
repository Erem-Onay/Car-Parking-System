library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-----------
entity top is
generic (
c_clkfreq		: integer := 100_000_000;
I2C_BUS_CLK		: integer := 400_000;
DEVICE_ADDR	: STD_LOGIC_VECTOR(6 DOWNTO 0) := "1001011"
);
port (
clk				: in std_logic;
RST_N 	        : IN STD_LOGIC;
SDA 	        : INOUT STD_LOGIC;
SCL 	        : INOUT STD_LOGIC;
TX 		        : OUT STD_LOGIC;
rx_i            : in STD_LOGIC
--LED 	        : OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
);
end top;
-----------

architecture Behavioral of top is

-------------------
component GY_530 IS
generic (
	c_clkfreq			: INTEGER := 100_000_000;
	I2C_BUS_CLK		: INTEGER := 400_000;
	DEVICE_ADDR		: STD_LOGIC_VECTOR(6 DOWNTO 0) := "1001011"
);
port ( 
	CLK 			: IN STD_LOGIC;
	RST_N 			: IN STD_LOGIC;
	SCL 			: INOUT STD_LOGIC;
	SDA 			: INOUT STD_LOGIC;
	INTERRUPT 		: OUT STD_LOGIC;
	TEMP 			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0) -- sensör 2 byte gönderiyor gibi kabul ettim.
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
-------------------

-------------------
-- UART_TX signals
signal tx_start 	: std_logic := '0';
signal tx_done_tick : std_logic := '0';
signal din 			: std_logic_vector (7 downto 0) := (others => '0');

-- GY_530 signals
signal INTERRUPT 	: std_logic := '0';
signal TEMP		 	: std_logic_vector (12 downto 0) := (others => '0');

-- UART_RX signals
signal dout			: std_logic_vector (7 downto 0) := (others => '0');
signal rx_done_tick : std_logic := '0';


signal gear : std_logic := '0';
-------------------

begin
-------------------
GY_530_i : GY_530
GENERIC MAP(
	c_clkfreq		=> c_clkfreq		,
	I2C_BUS_CLK	=> I2C_BUS_CLK	,
	DEVICE_ADDR	=> DEVICE_ADDR	
)
PORT MAP( 
	CLK 		=> CLK 		    ,
	RST_N 		=> RST_N 		,
	SCL 		=> SCL 		    ,
	SDA 		=> SDA 		    ,
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
-------------------


process (CLK) begin
if (rising_edge(CLK)) then

	DIN	<= TEMP(7 downto 0);    -- Bu koda göre ilk olarak temp'in high byte'? sonra low byte'? gönderilecek.
                                -- sensörden gelen iki byte verinin TEMP'e at?laca??n? varsayd?m.
	if (INTERRUPT = '1') then
		DIN			<= TEMP(15 downto 8);
		TX_START	<= '1';
	end if;		

	if (TX_DONE_TICK = '1') then
		TX_START	<= '0';
	end if;
	---
	
	---
	if (RX_DONE_TICK = '1') then
	    if( dout = "01010010") then  -- R, geri vites
	       gear <= '1';
	    elsif ( dout = "01000110") then --F, ieri vites
	       gear <= '0';
	    else 
	       gear <= gear;
	    end if;
	end if;
	---
		
	
end if;
end process;


end Behavioral;


