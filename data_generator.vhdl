-- Copyright (C) 2025 Joey Reed
-- Released under the MIT license.  See LICENSE for copying permission
-- --
-- Project     Device Driver for the AD5541a 16-bit digital to analog converter from Analog Devices
-- Purpose     Generates canned data for the DAC driver
-- Author      Joey Reed (joey@thebitstream.me)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity data_generator is 
    port(
        clk          : in  std_logic;
        rst          : in  std_logic;
        m_axis_data  : out std_logic_vector(15 downto 0);
        m_axis_valid : out std_logic;
        s_axis_ready : in  std_logic
    );
end entity;

architecture data_generator of data_generator is 

    signal cnt : unsigned(3 downto 0) := 4d"0";

    type ROM_4x16 is array(3 downto 0) of std_logic_vector(15 downto 0);

    signal rom: ROM_4x16 := (16x"c0de", 16x"feed", 16x"cafe", 16x"b0ba");
begin

    m_axis_valid <= '1';

    process (clk) begin
        if rising_edge(clk) then 
            if rst = '1' then 
                cnt <= 4d"0";
                m_axis_data <= 16d"0";
            else 
                if m_axis_valid = '1' and s_axis_ready = '1' then 
                    m_axis_data <= rom(to_integer(cnt));
                    cnt <= cnt + 1;
                end if;
            end if; 
        end if;
    end process;
end architecture;
