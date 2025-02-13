-- Copyright (C) 2025 Joey Reed
-- Released under the MIT license.  See LICENSE for copying permission
-- --
-- Project     Device Driver for the AD5541a 16-bit digital to analog converter from Analog Devices
-- Purpose     Top-level module
-- Author      Joey Reed (joey@thebitstream.me)


library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;


entity dac_ad5541a is
    generic (
        MCLK_CYCLES_PER_DAC_CLK_CYCLE:       unsigned(7 downto 0) := 8d"100";
        MCLK_CYCLES_PER_SPI_CLK_CYCLE:       unsigned(7 downto 0) := 8d"8";
        MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE : unsigned(7 downto 0) := 8d"4"
    );
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        en           : in  std_logic;    
        s_axis_valid : in  std_logic; 
        m_axis_ready : out std_logic;
        s_axis_data  : in  std_logic_vector(15 downto 0);
        sclk         : out std_logic := '1';
        mosi         : out std_logic := '0';
        cs_n         : out std_logic := '1';
        ldac_n       : out std_logic := '0'
    );
end entity;

architecture dac of dac_ad5541a is 
    
    type state is (
        IDLE, 
        REQUEST_SAMPLE, 
        FRAME_START, 
        DATA, 
        FRAME_END, 
        DONE,
        CLEANUP
    );

    
    signal current_state: state;
    signal next_state: state;

    signal state_cnt : unsigned(15 downto 0) := 16d"0";

    signal spi_clk_posedge_cnt : unsigned(15 downto 0); 
    signal spi_clk_cnt : unsigned(15 downto 0); 

    signal data_in : std_logic_vector(15 downto 0) := 16d"0";

    signal spi_clk_negedge: std_logic;
    signal spi_clk_posedge: std_logic;

    signal spi_clock_is_running : std_logic := '0';
    signal spi_clock_is_done    : std_logic := '0';    

    -- counts the number of rising clock edges to determine when to request new sample.
    signal clock_count : unsigned(15 downto 0) := 16d"0";
begin 
    

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
        -- prevent inferred latch, 
        next_state <= current_state; 

        case current_state is
        when IDLE => 
            if en = '1' then 
                if clock_count = MCLK_CYCLES_PER_DAC_CLK_CYCLE-1 then
                    next_state <= REQUEST_SAMPLE;
                end if;
            else
                next_state <= IDLE;
            end if;
        when REQUEST_SAMPLE =>
            if en = '1' then
                next_state <= FRAME_START;
            else 
                next_state <= IDLE;
            end if;
        when FRAME_START =>
            if en = '1' then 
                next_state <= DATA;
            else 
                next_state <= IDLE;
            end if;
        when DATA =>
            if en = '1' then 
                if spi_clk_posedge_cnt = 16 then
                    next_state <= FRAME_END;
                end if;
            else 
                next_state <= IDLE;
            end if;
        when FRAME_END =>
            if en = '1' then 
                if spi_clk_posedge_cnt = 17 then
                    next_state <= DONE;
                end if;
            else
                next_state <= IDLE;
            end if;
        when DONE =>
            next_state <= CLEANUP;
        when CLEANUP =>
            next_state <= IDLE;
        when others => 
            next_state <= IDLE; 
        end case;
    end process;





    process (clk) begin
        if rising_edge(clk) then
            if rst = '1' then 
                state_cnt <= 16d"0";
            else 
                if current_state /= next_state then
                    state_cnt <= 16d"0";
                else 
                    state_cnt <= state_cnt+1;
                end if;
            end if; 
        end if;
    end process;


    
    process (clk) begin
        if rising_edge(clk) then
            if rst = '1' then 
                clock_count <= 16d"0";
            else 
                if clock_count = MCLK_CYCLES_PER_DAC_CLK_CYCLE-1 then
                    clock_count <= 16d"0";
                else 
                    clock_count <= clock_count+1;
                end if;
            end if; 
        end if;
    end process;

    -- AXI STREAM HAND SHAKING
    
    m_axis_ready <= '1' when (current_state = IDLE and next_state = REQUEST_SAMPLE) else '0';


    axis_handshake_proc: process (clk) begin

        if rising_edge(clk) then

            if rst = '1' then
                data_in <= 16d"0";
            else 
                if s_axis_valid = '1' and m_axis_ready = '1' then
                    data_in <= s_axis_data;
                end if;
            end if;
        end if;
    end process;

    spi_clock_process: process (clk) begin 
        if rising_edge(clk) then 
            if rst = '1' then 
                sclk <= '1';
            else 
                if spi_clock_is_running = '1' then 
                    if spi_clk_posedge = '1' then 
                        sclk <= '1';
                    elsif spi_clk_negedge = '1' then 
                        sclk <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;



    output_process: process (clk) begin
        if rising_edge(clk) then 
            if rst = '1' then 
                cs_n   <= '1';
                mosi   <= '0';
                ldac_n <= '0';
            else

                -- Might be a good idea to split up the SPI clock into it's own process,
                -- or have one state for transmission through the dac load register and behavior
                -- changes only based on the number of SPI clock rising edges
                case current_state is 
                    when IDLE =>
                        cs_n   <= '1';
                        mosi   <= '0';
                    when FRAME_START =>
                        cs_n <= '0';
                    when DATA =>
                        if spi_clk_negedge = '1' then
                            mosi <= data_in(to_integer(15 - spi_clk_posedge_cnt));
                        end if;
                    when FRAME_END =>
                        if spi_clk_negedge = '1' then
                            cs_n <= '1';
                            mosi <= '0';
                        end if;
                    when others =>
                        cs_n   <= '1';
                        mosi   <= '0';
                end case;
            end if;
        end if;
    end process;


    -- simple register to determine when the spi clock functionality should start
    process (clk) begin 
        if rising_edge(clk) then
            if current_state = FRAME_START then
                spi_clock_is_running <= '1';
            elsif current_state = DONE then 
                spi_clock_is_running <= '0';
            end if;
        end if;
    end process;
    
    
    spi_clk_posedge <= '1' when spi_clk_cnt = MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE else '0';
    spi_clk_negedge <= '1' when spi_clk_cnt = 0 else '0';
    
    -- Counter that produces SPI Clock
    process(clk) begin 
        if rising_edge(clk) then 
            if rst = '1' then 
                spi_clk_cnt <= 16d"0";
            else
            
                if spi_clock_is_running = '1' then 
                    if spi_clk_cnt = MCLK_CYCLES_PER_SPI_CLK_CYCLE-1 then
                        spi_clk_cnt <= 16d"0";
                    else 
                        spi_clk_cnt <= spi_clk_cnt + 1;
                    end if;
                elsif spi_clock_is_done = '1' then
                    spi_clk_cnt <= 16d"0";
                end if;
            end if;
        end if;
    end process;

    spi_clock_is_done <= '1' when current_state = CLEANUP else '0';

    -- Count rising edges of spi clock
    process(clk) begin 
        if rising_edge(clk) then 
            if rst = '1' then 
                spi_clk_posedge_cnt <= 16d"0";
            else
            
                if spi_clock_is_running = '1' then 
                    if spi_clk_posedge = '1' then 
                        spi_clk_posedge_cnt <= spi_clk_posedge_cnt + 1;
                    end if;
                elsif spi_clock_is_done = '1' then
                    spi_clk_posedge_cnt <= 16d"0";
                end if;
            end if;
        end if;
    end process;
end architecture;
