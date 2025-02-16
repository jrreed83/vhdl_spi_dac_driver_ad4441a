-- Copyright (C) 2025 Joey Reed
-- Released under the MIT license.  See LICENSE for copying permission
-- --
-- Project     Device Driver for the AD5541a 16-bit digital to analog converter from Analog Devices
-- Purpose     Basic testbench
-- Author      Joey Reed (joey@thebitstream.me)

library osvvm;
  use osvvm.ClockResetPkg.all;
  use osvvm.AlertLogPkg.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library std;





entity dac_ad5541a_tb is 
end entity;


architecture tb of dac_ad5541a_tb is 

    constant CLOCK_PERIOD: time := 10 ns;
    
    constant MCLK_CYCLES_PER_DAC_CLK_CYCLE      : natural := 200;
    constant MCLK_CYCLES_PER_SPI_CLK_CYCLE      : natural := 8; 
    constant MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE : natural := 4; 
    
    constant DAC_DATA_PERIOD     : time := CLOCK_PERIOD * MCLK_CYCLES_PER_DAC_CLK_CYCLE;
    constant SPI_CLOCK_PERIOD    : time := CLOCK_PERIOD * MCLK_CYCLES_PER_SPI_CLK_CYCLE;
    constant SPI_CLOCK_LOW_TIME  : time := SPI_CLOCK_PERIOD / 2;
    constant SPI_CLOCK_HIGH_TIME : time := SPI_CLOCK_PERIOD / 2;


    signal clk         : std_logic := '0';
    signal rst         : std_logic;
    signal en          : std_logic;
    
    signal m_axis_valid: std_logic;
    signal s_axis_ready: std_logic;
    signal m_axis_data : std_logic_vector(15 downto 0) := (others => '0');


    signal sclk        : std_logic;
    signal cs_n        : std_logic;
    signal mosi        : std_logic;
    signal ldac_n      : std_logic;
    signal adc_sample  : std_logic_vector(15 downto 0) := (others => '0');

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



    signal axi_transaction_done: boolean;


    procedure assert_eq(expected: time; actual: time; message: string) is 
    begin
        assert expected = actual report "Error! " & LF & 
            message & " : " & "expected " & to_string(expected) & ", but see " & to_string(actual)   
        severity failure;   
    end procedure;


    procedure assert_eq(expected: std_logic; actual: std_logic; message: string) is 
    begin
        assert expected = actual report "Error! " & LF & 
            message & " : " & "expected " & to_string(expected) & ", but see " & to_string(actual)   
        severity failure;   
    end procedure;
begin

    -- Check some of the absolute minimum values 
    AlertIfNot(SPI_CLOCK_PERIOD > 20 ns, "Absolute minimum SPI clock cycle time", failure);




    en <= '1';

    -- The D/A driver 
    dac_dut: dac_ad5541a
    generic map (
        MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE => MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE,
        MCLK_CYCLES_PER_SPI_CLK_CYCLE      => MCLK_CYCLES_PER_SPI_CLK_CYCLE,
        MCLK_CYCLES_PER_DAC_CLK_CYCLE      => MCLK_CYCLES_PER_DAC_CLK_CYCLE
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
    
        type array_16bit is array(natural range <>) of std_logic_vector(15 downto 0);
    
        constant test_vectors: array_16bit := (
            "0100100101100111",
            "0110010101011011",
            "1001000101001110",

            "0100100101100111",
            "0110010101011011",
            "1001000101001110",

            "0100100101100111",
            "0110010101011011",
            "1001000101001110"
        );

        variable address : natural := 0;

    begin
        m_axis_valid <= '1';
        while address < test_vectors'length loop
            wait until rising_edge(clk);

            if m_axis_valid = '1' and s_axis_ready = '1' then 
                m_axis_data <= test_vectors(address);
                address := address + 1;

                axi_transaction_done <= true; 
            end if;
        end loop;        
    end process;

    
    ------------------------------------------------------------------------------
    --
    -- Check that the DAC is putting out the ready signal at the correct data rate
    -- 
    -- Start calculating the delta between ready signals after the first one
    ------------------------------------------------------------------------------
    check_data_rate : process  
        variable t0 : time;
        variable dt : time;
    begin
        wait until s_axis_ready = '1';
        t0 := now;
        while true loop  
            wait until s_axis_ready = '1';
            dt := now-t0;
            t0 := now;
            
            AlertIfNotEqual(DAC_DATA_PERIOD, dt, "DAC data period");
        end loop;
        
    end process;


    
    ------------------------------------------------------------------------------
    --
    -- Check time that the chip-select line should be low for. It should begin
    -- low roughly for 16 SPI clock cycle periods
    -- 
    ------------------------------------------------------------------------------
    
    check_cs_low_duration: process 
        variable t0 : time;
        variable t1 : time;
    begin
        wait until cs_n = '0'; t0 := now;
        wait until cs_n = '1'; t1 := now;
        
        -- Check the time between the falling and rising edge of chip-select
        AlertIfNotEqual(16*SPI_CLOCK_PERIOD, t1-t0, "chip-select active low time");        
        
    end process;

    

    ------------------------------------------------------------------------------
    --
    -- T4: CS low to SCLK high setup
    -- 
    ------------------------------------------------------------------------------
    check_cs_low_to_sck_high: process 
        variable t0 : time;
        variable t1 : time;
    begin
        wait until cs_n = '0'; t0 := now;
        wait until sclk = '1'; t1 := now;
        -- make sure cs_n still low 
        
        AlertIfNotEqual('0', cs_n, "chip-select at first rising spi clock edge");
        -- Check the time between the falling and rising edge of chip-select
        
        AlertIfNotEqual(SPI_CLOCK_LOW_TIME, t1-t0, "chip-select low to spi clock high");
    end process;



    ------------------------------------------------------------------------------
    --
    -- T7: SCLK high to CS high setup
    --    
    ------------------------------------------------------------------------------
    check_cs_high_to_sck_high: process 
        variable t0 : time;
        variable t1 : time;
    begin
        wait until cs_n = '0'; t0 := now;
        
        -- Move through the rising edges of the spi clock until we get to the last one
        -- before the rising edge of the chip-select line
        for i in 1 to 16 loop 
            wait until sclk = '1';
        end loop;
        
        -- Measure the time-delta between the last rising 
        t0 := now;
        AlertIfNotEqual('0', cs_n, "chip-select at last spi clock rising edge in data");
        
        
        wait until cs_n = '1';
        t1 := now;

        AlertIfNotEqual(SPI_CLOCK_HIGH_TIME, t1-t0, "SPI clock high to ship-select setup time");
    end process;


    ------------------------------------------------------------------------------
    --
    -- T1, T2, T3: SPI clock cycle time, SPI clock high time, SPI clock low time
    --    
    ------------------------------------------------------------------------------
    sclk_cycle_time: process 
        variable t0: time;
        variable t1: time;
        variable t2: time;
    begin 
        -- Get to first rising edge of SPI Clock 
        wait until cs_n = '0';
        wait until sclk = '1';
        
        t0 := now;
        for i in 1 to 16 loop
        
            -- switch from low to high => low time
            wait until sclk = '0';  t1 := now; 
            AlertIfNotEqual(SPI_CLOCK_HIGH_TIME, t1-t0, "SPI clock high time");
        
            
            -- switch from high to low => high time
            wait until sclk = '1';  t2 := now;
            
            AlertIfNotEqual(SPI_CLOCK_LOW_TIME, t2-t1, "SPI clock low time");
            assert (t2-t0) = SPI_CLOCK_PERIOD;

            t0 := t2;
        end loop;
        
    end process;
    
    ----------------------------------------------------------------------------
    --
    -- T8, T9: Data setup and hold time
    --
    ----------------------------------------------------------------------------
    data_setup_and_hold: process 
        variable t0: time;
        variable t1: time;
    begin 
        wait until cs_n = '0';
    end process;



    ----------------------------------------------------------------------------
    --
    -- Data Check
    --
    ----------------------------------------------------------------------------

    check_data: process 
        variable sample : std_logic_vector(15 downto 0) := (others => '0');
    begin
        wait until cs_n = '0';
    
        for i in 15 downto 0 loop 
            wait until sclk = '1';
            sample(i) := mosi;
        end loop;

        wait until cs_n = '1';
        
        adc_sample <= sample;
        
        sample := (others => '0');
    end process; 

    ----------------------------------------------------------------------
    --
    -- COMPARE ADC and DAC
    --    The ADC is two frames behind the AXI Stream master.  That's 
    --    why I'm including a three element register.
    --
    ----------------------------------------------------------------------
    process 
        variable packet_count : natural := 0;

        variable reg0 : std_logic_vector(15 downto 0) := (others => '0');
        variable reg1 : std_logic_vector(15 downto 0) := (others => '0');
        variable reg2 : std_logic_vector(15 downto 0) := (others => '0');
    begin 
        -- 'transaction toggles whenever signal assigned to, even if same value.
        -- triggering off 'm_axis_data' doesn't seem to work?  There was something
        -- screwy with the transactions because I initialized the m_axis_data signal...

        wait on axi_transaction_done'transaction; --transaction_done'transaction;
        
        
        --wait on m_axis_data'transaction;
        reg0 := reg1;
        reg1 := reg2;
        reg2 := m_axis_data; 
      

        --report "TRANSACTION" & " true " & to_hex_string(m_axis_data) & " reg0 " & to_hex_string(reg0) & " recovered " & to_hex_string(adc_sample);

        wait until cs_n = '1';

            --report "TRANSACTION" & " true " & to_hex_string(reg0) & " recovered " & to_hex_string(adc_sample);
        AlertIfNotEqual(reg0, adc_sample, "Expected vs detected data");

        
        if packet_count = 6 then 
            report(to_string(now, 1 ns) & LF & "******* All Tests Passed! ********" & LF);
            std.env.finish;
        end if;
        packet_count := packet_count + 1;

    end process;

    
end architecture;
