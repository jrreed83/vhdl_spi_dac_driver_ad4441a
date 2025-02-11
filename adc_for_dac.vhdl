-- Copyright (C) 2025 Joey Reed
-- Released under the MIT license.  See LICENSE for copying permission
-- --
-- Project     Device Driver for the AD5541a 16-bit digital to analog converter from Analog Devices
-- Purpose     An analog-to-digital converter like device used to validate that the DAC driver is working properly
-- Author      Joey Reed (joey@thebitstream.me)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_for_dac is 
    port(
        clk: in std_logic;
        rst: in std_logic;
        
        sclk: in std_logic;
        cs_n: in std_logic;
        mosi: in std_logic;
        
        adc_sample: out std_logic_vector(15 downto 0) := 16d"0"
    );
end entity;

architecture adc_for_dac of adc_for_dac is 
    type state is (IDLE, SAMPLE, DONE);

    signal current_state: state;
    signal next_state: state;

    signal state_counter: unsigned(5 downto 0);
    signal falling_edge_cs_n: std_logic;
    signal rising_edge_sclk: std_logic;
    signal rising_edge_sclk_counter: unsigned(5 downto 0);
    signal previous_cs_n: std_logic;
    signal previous_sclk: std_logic;

    signal data_sample: std_logic_vector(15 downto 0);
begin

    -- State Machine transition logic
    process (clk) begin 
        if rising_edge(clk) then
            if rst = '1' then 
                current_state <= IDLE;
            else 
                current_state <= next_state;
            end if;
        end if;
    end process;

    process (all) begin 
        next_state <= current_state;
        case current_state is
            when IDLE =>
                if falling_edge_cs_n = '1' then 
                    next_state <= SAMPLE;
                end if;
            when SAMPLE =>
                if rising_edge_sclk_counter = 6d"16" then
                    next_state <= DONE;
                end if;
            when DONE =>
                next_state <= IDLE;
            when others =>
                next_state <= IDLE;
        end case;
    end process;






    -- Track the falling edge of the chip select line and the rising_edge
    -- edge of the SPI clock signal
    process (clk) begin 
        if rising_edge(clk) then 
            previous_cs_n <= cs_n;
            previous_sclk <= sclk;
        end if;
    end process;
    falling_edge_cs_n <= '1' when (cs_n = '0' and previous_cs_n = '1') else '0';
    rising_edge_sclk  <= '1' when (sclk = '1' and previous_sclk = '0') else '0'; 

    -- Count the number of rising edges in the SPI clock 
    process (clk) begin 
        if rising_edge(clk) then 
            if rst = '1' then 
                rising_edge_sclk_counter <= 6d"0";
            else 
                if current_state = SAMPLE then 
                    if rising_edge_sclk = '1' then 
                        rising_edge_sclk_counter <= rising_edge_sclk_counter + 1;
                    end if;
                elsif current_state = DONE then 
                    rising_edge_sclk_counter <= 6d"0";
                end if;
            end if;
        end if;
    end process;
    
    -- Sample the MOSI data line on the rising edge of the clock
    -- 
    process (clk) begin 
        if rising_edge(clk) then 
            if rst = '1' then 
                data_sample <= 16d"0";
            else
                if current_state = SAMPLE then 
                    if rising_edge_sclk = '1' then 
                        data_sample(15-to_integer(rising_edge_sclk_counter)) <= mosi;
                    end if; 
                elsif current_state = DONE then
                    adc_sample <= data_sample;
                end if;
            end if;
        end if;
    end process;


    -- State counter: resets to 0 at a state transition
    process (clk) begin
        if rising_edge(clk) then 
            if rst = '1' then 
                state_counter <= 6d"0";
            else 
                if current_state /= next_state then 
                    state_counter <= 6d"0";
                else 
                    state_counter <= state_counter + 1;
                end if;
            end if;
        end if;
    end process;


    

end architecture;
