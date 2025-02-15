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


    component adc_for_dac is 
        port (
            clk        : in std_logic;
            rst        : in std_logic;
            mosi       : in std_logic;
            cs_n       : in std_logic;
            sclk       : in std_logic;
            
            adc_sample : out std_logic_vector(15 downto 0)
        );
    end component;





    type ROM_4x16 is array(3 downto 0) of std_logic_vector(15 downto 0);

    signal memory_address : unsigned(1 downto 0) := 2d"0";
    signal rom            : ROM_4x16 := (16x"c0de", 16x"feed", 16x"cafe", 16x"b0ba");


    -- Should put in my own package
    --procedure CreateEnable (
    --    signal   Clock  : in  std_logic;
    --    signal   Reset  : in  std_logic;
    --    constant Delay  : in  time := 10 ns; 
    --    signal   Enable : out std_logic
    --) is 
    --begin
    --    Enable <= '0';
    --    wait until not Reset;
    --    wait for Delay;
    --    wait until rising_edge(Clock);
    --    Enable <= '1';
    --    wait;
    --end procedure;


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

    --CreateEnable (
    --    Clock  => clk,
    --    Reset  => rst,
    --    Enable => en 
    --);
    
    

    -- Create Stimulus 
    m_axis_valid <= '1';
    stimulus_generator: process (clk) is begin
        if rising_edge(clk) then 
            if rst = '1' then 
                m_axis_data    <= 16d"0";
                memory_address <= 2d"0";
            else 
                if m_axis_valid = '1' and s_axis_ready = '1' then 
                    m_axis_data      <= rom(to_integer(memory_address));
                    memory_address   <= memory_address + 1;
                    transaction_done <= true;
                end if;
            end if; 
        end if;
    end process;

    --transaction_done <= true when  m_axis_valid = '1' and s_axis_ready = '1' else false; 
    -- Want this to be the thing that checks the stimulus.  
    -- The ADC for the DAC
    adc_dut: adc_for_dac 
    port map (
        clk        => clk,
        rst        => rst,
        sclk       => sclk,
        mosi       => mosi,
        cs_n       => cs_n,
        adc_sample => adc_sample
    );

    
    ------------------------------------------------------------------------------
    --
    -- Check that the DAC is putting out the ready signal at the correct data rate
    -- 
    ------------------------------------------------------------------------------
    check_data_rate : process  
        variable t0            : time := 0 ns;
        variable dt            : time;
        variable count         : natural := 0;
        constant DAC_DATA_RATE : time := CLOCK_PERIOD * 200; 
    begin
        wait until s_axis_ready = '1';
        
        dt := now-t0;
        t0 := now;
        if count > 0 then 
            --report "******** " & to_string(dt);
            assert dt = DAC_DATA_RATE;
        end if;
        count := count + 1;
        
    end process;


    
    ------------------------------------------------------------------------------
    --
    -- Check that the DAC is putting out the ready signal at the correct data rate
    -- 
    ------------------------------------------------------------------------------
    check_spi: process 
        
        variable t0               : time  := 0 ns;
        variable t1               : time  := 0 ns;
        variable t2               : time  := 0 ns;
        variable t3               : time  := 0 ns;
        variable t4               : time  := 0 ns;
        constant MINIMUM_BIT_TIME : time  := 20 ns;
    begin
        wait until cs_n = '0'; t0 := now;

        -- 15
        wait until sclk = '1'; t1 := now;
        wait until sclk = '0';
        -- 14
        wait until sclk = '1';
        wait until sclk = '0';
        -- 13
        wait until sclk = '1';
        wait until sclk = '0';
        -- 12
        wait until sclk = '1';
        wait until sclk = '0';
        -- 11
        wait until sclk = '1';
        wait until sclk = '0';
        -- 10
        wait until sclk = '1';
        wait until sclk = '0';
        -- 9
        wait until sclk = '1';
        wait until sclk = '0';
        -- 8
        wait until sclk = '1';
        wait until sclk = '0';
        -- 7
        wait until sclk = '1';
        wait until sclk = '0';
        -- 6
        wait until sclk = '1';
        wait until sclk = '0';
        -- 5
        wait until sclk = '1';
        wait until sclk = '0';
        -- 4
        wait until sclk = '1';
        wait until sclk = '0';
        -- 3
        wait until sclk = '1';
        wait until sclk = '0';
        -- 2
        wait until sclk = '1';
        wait until sclk = '0';
        -- 1
        wait until sclk = '1';
        wait until sclk = '0';
        -- 0 
        wait until sclk = '1';

        assert cs_n = '0';

        -- Check CS low to SCLK high setup
        assert (t1-t0) > 4 ns;
        --t2 := now;
        wait until cs_n = '1'; t3 := now;
        
        -- Check the time between the falling and rising edge of chip-select
        assert (t3-t0) > 16 * MINIMUM_BIT_TIME; 
        
        
    end process;
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
        reg0  := reg1;
        reg1  := reg2;
        reg2  := m_axis_data; 
        
        report to_hex_string(m_axis_data) & " " & to_hex_string(adc_sample) & " " & to_string(now + CLOCK_PERIOD);
        if count >= 2 then 
            assert adc_sample = reg0 report "Mismatch between DAC and ADC";
        end if;

        count := count + 1;
    end process;

    
end architecture;
