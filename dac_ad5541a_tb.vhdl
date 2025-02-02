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
            sclk:   out std_logic;
            mosi:   out std_logic;
            cs_n:   out std_logic;
            ldac_n: out std_logic
        );
    end component; 

    component data_generator is 
        port (
            clk: in std_logic;
            rst: in std_logic;

            m_axis_valid: out std_logic;
            s_axis_ready: in  std_logic;
            m_axis_data:  out std_logic_vector(15 downto 0)
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
        cs_n         => cs_n,
        ldac_n       => ldac_n
    );

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
