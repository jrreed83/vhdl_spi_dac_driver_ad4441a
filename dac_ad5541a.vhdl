library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity dac_ad5541a is 
    port (
        clk: in std_logic;
        rst: in std_logic;
        en:  in std_logic;    

        s_axis_valid: in  std_logic; 
        m_axis_ready: out std_logic;
        s_axis_data:  in  std_logic_vector(15 downto 0);

        sclk: out std_logic;
        mosi: out std_logic;
        cs_n: out std_logic
    );
end entity;

architecture dac of dac_ad5541a is 

    constant MCLK_CYCLES_PER_DAC_CLK_CYCLE: unsigned(7 downto 0) := 8d"100";
    constant MCLK_CYCLES_PER_SPI_CLK_CYCLE: unsigned(7 downto 0) := 8d"8";
    constant MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE : unsigned(7 downto 0) := 8d"4";
    type state is (IDLE, LOAD, START, XMIT, FINISH, DONE);

    
    signal current_state: state;
    signal next_state: state;

    signal state_cnt : unsigned(15 downto 0) := 16d"0";

    signal sclk_posedge_cnt : unsigned(15 downto 0); 
    signal sclk_cnt : unsigned(15 downto 0); 

    signal data_in : std_logic_vector(15 downto 0);

    signal sclk_negedge: std_logic;
    signal sclk_posedge: std_logic;
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
                if state_cnt = MCLK_CYCLES_PER_DAC_CLK_CYCLE-1 then
                    next_state <= LOAD;
                end if;
            else
                next_state <= IDLE;
            end if;
        when LOAD =>
            if en = '1' then
                next_state <= START;
            else 
                next_state <= IDLE;
            end if;
        when START =>
            if en = '1' then 
                next_state <= XMIT;
            else 
                next_state <= IDLE;
            end if;
        when XMIT =>
            if en = '1' then 
                if sclk_posedge_cnt = 16 then
                    next_state <= FINISH;
                end if;
            else 
                next_state <= IDLE;
            end if;
        when FINISH =>
            if en = '1' then 
                if sclk_posedge_cnt = 17 then
                    next_state <= DONE;
                end if;
            else
                next_state <= IDLE;
            end if;
        when DONE =>
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


    -----
    -- AXI STREAM HAND SHAKING
    -----
    m_axis_ready <= '1' when (current_state = IDLE and next_state = LOAD) else '0';


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


    output_process: process (clk) begin
        if rising_edge(clk) then 
            if rst = '1' then 
                cs_n <= '1';
                sclk <= '1';
                mosi <= '0';
            else 
                case current_state is 
                    when IDLE =>
                        cs_n <= '1';
                        sclk <= '1';
                        mosi <= '0';
                    when START =>
                        cs_n <= '0';
                    when XMIT =>
                        if sclk_negedge = '1' then
                            sclk <= '0';
                            mosi <= data_in(to_integer(15 - sclk_posedge_cnt));
                        elsif sclk_posedge = '1' then 
                            sclk <= '1';
                        end if;
                    when FINISH =>
                        if sclk_negedge = '1' then
                            sclk <= '0';
                            cs_n <= '1';
                            mosi <= '0';
                        elsif sclk_posedge = '1' then 
                            sclk <= '1';
                        end if;
                    when others =>
                        cs_n <= '1';
                        sclk <= '1';
                        mosi <= '0';
                end case;
            end if;
        end if;
    end process;


    process(clk) begin 
        if rising_edge(clk) then 
            if rst = '1' then 
                sclk_cnt <= 16d"0";
                sclk_posedge_cnt <= 16d"0";
            else 
                if current_state = XMIT or current_state = FINISH then
                    if sclk_cnt = MCLK_CYCLES_PER_SPI_CLK_CYCLE-1 then
                        sclk_cnt <= 16d"0";
                    else 
                        sclk_cnt <= sclk_cnt + 1;
                    end if;

                    if sclk_posedge = '1' then 
                        sclk_posedge_cnt <= sclk_posedge_cnt + 1;
                    end if;
                elsif current_state = IDLE then 
                    sclk_cnt <= 16d"0";
                    sclk_posedge_cnt <= 16d"0";
                end if;
            end if;
        end if;
    end process;


    sclk_posedge <= '1' when sclk_cnt = MCLK_CYCLES_PER_HALF_SPI_CLK_CYCLE else '0';
    sclk_negedge <= '1' when sclk_cnt = 0 else '0';
end architecture;
