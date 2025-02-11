-- Copyright (C) 2025 Joey Reed
-- Released under the MIT license.  See LICENSE for copying permission
-- --
-- Project     Device Driver for the AD5541a 16-bit digital to analog converter from Analog Devices
-- Purpose     Basic testbench
-- Author      Joey Reed (joey@thebitstream.me)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity dac_ad5541a_tb is 
end entity;




architecture tb of dac_ad5541a_tb is 
    
    constant CLOCK_PERIOD: time := 10 ns;

    signal clk         : std_logic;
    signal rst         : std_logic;
    signal en          : std_logic;
    
    signal m_axis_valid: std_logic;
    signal s_axis_ready: std_logic;
    signal m_axis_data : std_logic_vector(15 downto 0);


    signal sclk        : std_logic;
    signal cs_n        : std_logic;
    signal mosi        : std_logic;
    signal ldac_n      : std_logic;
    
    component dac_ad5541a is
        generic(
            MCLK_CYCLES_PER_DAC_CLK_CYCLE      : unsigned(7 downto 0);
            MCLK_CYCLES_PER_SPI_CLK_CYCLE      : unsigned(7 downto 0);
            MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE : unsigned(7 downto 0)
        );
        port(
            -- Basic inputs
            clk          : in std_logic;
            rst          : in std_logic;
            en           : in std_logic;
            -- AXI Signals
            s_axis_valid : in  std_logic;
            m_axis_ready : out std_logic;
            s_axis_data  : in  std_logic_vector(15 downto 0);
            -- SPI outputs
            sclk         : out std_logic;
            mosi         : out std_logic;
            cs_n         : out std_logic;
            ldac_n       : out std_logic
        );
    end component; 


    component adc_for_dac is 
        port (
            clk:  in std_logic;
            rst:  in std_logic;
            mosi: in std_logic;
            cs_n: in std_logic;
            sclk: in std_logic;
            
            adc_sample: out std_logic_vector(15 downto 0)
        );
    end component;





    type ROM_4x16 is array(3 downto 0) of std_logic_vector(15 downto 0);

    signal memory_address : unsigned(1 downto 0) := 2d"0";
    signal rom            : ROM_4x16 := (16x"c0de", 16x"feed", 16x"cafe", 16x"b0ba");


begin
    
    -- The D/A driver 
    dac_dut: dac_ad5541a
    generic map (
        MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE => 8d"4",
        MCLK_CYCLES_PER_SPI_CLK_CYCLE      => 8d"8",
        MCLK_CYCLES_PER_DAC_CLK_CYCLE      => 8d"100"
    )
    port map (
        clk          => clk, 
        rst          => rst,
        en           => en,
        m_axis_ready => s_axis_ready,
        s_axis_valid => m_axis_valid,
        s_axis_data  => m_axis_data,

        sclk         => sclk,
        mosi         => mosi,
        cs_n         => cs_n,
        ldac_n       => ldac_n
    );


    clock_process: process
    begin
        clk <= '0'; wait for CLOCK_PERIOD/2;
        clk <= '1'; wait for CLOCK_PERIOD/2;    
    end process;

    reset_process: process 
    begin
        rst <= '0';
        wait for 100 ns;
        wait until rising_edge(clk);
        rst <= '1';
        wait for 30 ns;
        rst <= '0';
        wait;    
    end process;

    enable_process: process 
    begin
        en <= '1';
        wait;        
    end process;


    m_axis_valid <= '1';
    stimulus_generator: process (clk) begin
        if rising_edge(clk) then 
            if rst = '1' then 
                m_axis_data    <= 16d"0";
                memory_address <= 2d"0";
            else 
                if m_axis_valid = '1' and s_axis_ready = '1' then 
                    m_axis_data    <= rom(to_integer(memory_address));
                    memory_address <= memory_address + 1;
                end if;
            end if; 
        end if;
    end process;

    -- The ADC for the DAC
    adc_dut: adc_for_dac 
    port map (
        clk  => clk,
        rst  => rst,
        sclk => sclk,
        mosi => mosi,
        cs_n => cs_n
    );

end architecture;
