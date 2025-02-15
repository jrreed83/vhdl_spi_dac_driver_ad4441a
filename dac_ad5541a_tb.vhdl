-- Copyright (C) 2025 Joey Reed
-- Released under the MIT license.  See LICENSE for copying permission
-- --
-- Project     Device Driver for the AD5541a 16-bit digital to analog converter from Analog Devices
-- Purpose     Basic testbench
-- Author      Joey Reed (joey@thebitstream.me)

library osvvm;
  use osvvm.ClockResetPkg.all;


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library std;





entity dac_ad5541a_tb is 
end entity;


architecture tb of dac_ad5541a_tb is 

    constant CLOCK_PERIOD: time := 10 ns;

    signal clk         : std_logic := '0';
    signal rst         : std_logic;
    signal en          : std_logic;
    
    signal m_axis_valid: std_logic;
    signal s_axis_ready: std_logic;
    signal m_axis_data : std_logic_vector(15 downto 0);


    signal sclk        : std_logic;
    signal cs_n        : std_logic;
    signal mosi        : std_logic;
    signal ldac_n      : std_logic;
    signal adc_sample  : std_logic_vector(15 downto 0);

    component dac_ad5541a is
        generic(
            MCLK_CYCLES_PER_DAC_CLK_CYCLE      : natural;
            MCLK_CYCLES_PER_SPI_CLK_CYCLE      : natural; 
            MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE : natural  
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


    --component adc_for_dac is 
    --    port (
    --        clk        : in std_logic;
    --        rst        : in std_logic;
    --        mosi       : in std_logic;
    --        cs_n       : in std_logic;
    --        sclk       : in std_logic;
    --        
    --        adc_sample : out std_logic_vector(15 downto 0)
    --    );
    --end component;





    --type ROM_4x16 is array(3 downto 0) of std_logic_vector(15 downto 0);

    --signal memory_address : unsigned(1 downto 0) := 2d"0";
    --signal rom            : ROM_4x16 := (16x"c0de", 16x"feed", 16x"cafe", 16x"b0ba");

    -- For transaction 
    signal transaction_done: boolean;


begin
   

    en <= '1';

    -- The D/A driver 
    dac_dut: dac_ad5541a
    generic map (
        MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE => 4,
        MCLK_CYCLES_PER_SPI_CLK_CYCLE      => 8,
        MCLK_CYCLES_PER_DAC_CLK_CYCLE      => 200
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

    
    osvvm.ClockResetPkg.CreateClock (
        Clk    => clk, 
        Period => CLOCK_PERIOD
    );

    osvvm.ClockResetPkg.CreateReset (
        Reset       => rst, 
        ResetActive => '1', 
        Clk         => clk, 
        Period      => 50 ns
    );
    
    
    stimulus_generator: process 
        variable count : natural := 0;
    
        type array_16bit is array(0 to 2) of std_logic_vector(15 downto 0);
    
        constant test_vectors: array_16bit := (
            "0100100101100111",
            "0110010101011011",
            "1001000101001110"
        );

        variable address : natural := 0;

    begin
        m_axis_valid <= '1';
        m_axis_data  <= (others => '0');
        while address < test_vectors'length loop
            wait until rising_edge(clk);

            if m_axis_valid = '1' and s_axis_ready = '1' then 
                m_axis_data      <= test_vectors(address);
                transaction_done <= true;
                address := address + 1;
            end if;
        end loop;
        std.env.finish;        
    end process;

    
    ------------------------------------------------------------------------------
    --
    -- Check that the DAC is putting out the ready signal at the correct data rate
    -- 
    --    Start calculating the delta between readdy signals after the first one
    ------------------------------------------------------------------------------
    check_data_rate : process  
        variable t0            : time := 0 ns;
        variable dt            : time;
        constant DAC_DATA_RATE : time := CLOCK_PERIOD * 200; 
    begin
        wait until s_axis_ready = '1' and rising_edge(clk);
        t0 := now;
        while true loop  
            wait until s_axis_ready = '1' and rising_edge(clk);
            dt := now-t0;
            t0 := now; 
            assert dt = DAC_DATA_RATE report "Data Rate incorrect" severity failure;
        end loop;
        
    end process;


    
    ------------------------------------------------------------------------------
    --
    -- Check chip select
    -- 
    ------------------------------------------------------------------------------
    
    check_cs_low_duration: process 
        variable t0               : time    := 0 ns;
        variable t1               : time    := 0 ns;
        constant MINIMUM_BIT_TIME : time    := 20 ns;
    begin
        wait until cs_n = '0'; t0 := now;
        wait until cs_n = '1'; t1 := now;
        
        -- Check the time between the falling and rising edge of chip-select
        assert (t1-t0) > 16 * MINIMUM_BIT_TIME; 
        
    end process;



 --   check_spi_output: process 
 --       variable count            : natural := 0;
 --       variable t0               : time    := 0 ns;
 --       variable t1               : time    := 0 ns;
 --       variable t2               : time    := 0 ns;
 --       variable t3               : time    := 0 ns;
 --       variable t4               : time    := 0 ns;
 --       constant MINIMUM_BIT_TIME : time    := 20 ns;
 --       variable sample           : std_logic_vector(15 downto 0) := (others => '0');
 --   begin
 --       wait until cs_n = '0'; t0 := now;
--
--        -- 15
--        wait until sclk = '1'; t1 := now;
--        sample(15) := mosi;
--        wait until sclk = '0';
--        -- 14
--        wait until sclk = '1';
--        sample(14) := mosi;
--        wait until sclk = '0';
--        -- 13
--        wait until sclk = '1';
--        sample(13) := mosi;
--        wait until sclk = '0';
--        -- 12
--        wait until sclk = '1';
--        sample(12) := mosi;
--        wait until sclk = '0';
--        -- 11
--        wait until sclk = '1';
--        sample(11) := mosi;
--        wait until sclk = '0';
--        -- 10
--        wait until sclk = '1';
--        sample(10) := mosi;
--        wait until sclk = '0';
--        -- 9
--        wait until sclk = '1';
--        sample(9) := mosi;
--        wait until sclk = '0';
--        -- 8
--        wait until sclk = '1';
--        sample(8) := mosi;
--        wait until sclk = '0';
--        -- 7
--        wait until sclk = '1';
--        sample(7) := mosi;
--        wait until sclk = '0';
--        -- 6
--        wait until sclk = '1';
--        sample(6) := mosi;
--        wait until sclk = '0';
--        -- 5
 --       wait until sclk = '1';
--        sample(5) := mosi;
--        wait until sclk = '0';
--        -- 4
--        wait until sclk = '1';
--        sample(4) := mosi;
--        wait until sclk = '0';
--        -- 3
--        wait until sclk = '1';
--        sample(3) := mosi;
--        wait until sclk = '0';
--        -- 2
--        wait until sclk = '1';
--        sample(2) := mosi;
--        wait until sclk = '0';
--        -- 1
--        wait until sclk = '1';
--        sample(1) := mosi;
--        wait until sclk = '0';
--        -- 0 
--        wait until sclk = '1';
--        sample(0) := mosi;
--
--
--        assert cs_n = '0';
--        
--        adc_sample <= sample;
--        
--        -- Check CS low to SCLK high setup
--        assert (t1-t0) > 4 ns;
--        --t2 := now;
--        wait until cs_n = '1'; t3 := now;
        
        -- Check the time between the falling and rising edge of chip-select
--        assert (t3-t0) > 16 * MINIMUM_BIT_TIME; 
--        
--        if count > 0 then 
--            report "DATA: " & to_hex_string(sample);
--        end if;
--        count := count + 1;
--    end process;
    ----------------------------------------------------------------------
    --
    -- COMPARE ADC and DAC
    --    The ADC is two frames behind the AXI Stream master.  That's 
    --    why I'm including a three element register.
    --
    ----------------------------------------------------------------------
    process 
        variable count : natural := 0;

        variable reg0  : std_logic_vector(15 downto 0) := (others => '0');
        variable reg1  : std_logic_vector(15 downto 0) := (others => '0');
        variable reg2  : std_logic_vector(15 downto 0) := (others => '0');
    begin 
        -- 'transaction toggles whenever signal assigned to, even if same value.
        wait on transaction_done'transaction;
        report "TRANSACTION TRIGGERED " & " " & to_string(now);
--        reg0  := reg1;
--        reg1  := reg2;
--        reg2  := m_axis_data; 
--      
 --       wait until cs_n = '1';
 --       wait for 1 ns;
 --       report "TRANSACTION" & " true " & to_hex_string(m_axis_data) & " recovered " & to_hex_string(adc_sample);
 --       if count >= 2 then 
--            assert adc_sample = reg0 report "Mismatch between DAC and ADC";
--        end if;

--        count := count + 1;
    end process;

    
end architecture;
