library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;

entity dac_ad5541a_tb is 
end entity;

architecture tb of dac_ad5541a_tb is 
    signal clk: std_logic;
    signal rst: std_logic;
    signal en:  std_logic;
    
    signal m_axis_valid: std_logic;
    signal s_axis_ready: std_logic;
    signal m_axis_data:  std_logic_vector(15 downto 0);


    signal sclk:   std_logic;
    signal cs_n:   std_logic;
    signal mosi:   std_logic;
    signal ldac_n: std_logic;
    
    component dac_ad5541a is 
        port(
            -- Basic inputs
            clk: in std_logic;
            rst: in std_logic;
            en:  in std_logic;
            -- AXI Signals
            s_axis_valid: in  std_logic;
            m_axis_ready: out std_logic;
            s_axis_data:  in  std_logic_vector(15 downto 0);
            -- SPI outputs
            sclk: out std_logic;
            mosi: out std_logic;
            cs_n: out std_logic
            );
    end component; 

    component data_generator is 
        port (
            clk: in std_logic;
            rst: in std_logic;
            m_axis_valid: out std_logic;
            s_axis_ready: in std_logic;
            m_axis_data: out std_logic_vector(15 downto 0)
        );
    end component;


    constant CLOCK_PERIOD: time := 10 ns;
begin
    
    clk_process: process
    begin
        clk <= '0'; wait for CLOCK_PERIOD/2;
        clk <= '1'; wait for CLOCK_PERIOD/2;    
    end process;

    rst_process: process 
    begin
        rst <= '0';
        wait for 100 ns;
        wait until rising_edge(clk);
        rst <= '1';
        wait for 30 ns;
        rst <= '0';
        wait;    
    end process;

    en_process: process 
    begin
        en <= '1';
        wait;
    end process;

    --process begin
    --    m_axis_valid <= '1';
    --    m_axis_data  <= 16x"feed";
    --    wait;
    --end process;
    -- The data generator 
    gen_dut: data_generator 
    port map (
        clk          => clk,
        rst          => rst,
        m_axis_data  => m_axis_data,
        m_axis_valid => m_axis_valid,
        s_axis_ready => s_axis_ready
    );

    -- The D/A driver 
    dac_dut: dac_ad5541a 
    port map (
        clk          => clk, 
        rst          => rst,
        en           => en,
        m_axis_ready => s_axis_ready,
        s_axis_valid => m_axis_valid,
        s_axis_data  => m_axis_data,

        sclk         => sclk,
        mosi         => mosi,
        cs_n         => cs_n
    ); 

end architecture;
