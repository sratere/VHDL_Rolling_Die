----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.04.2025 10:53:29
-- Design Name: 
-- Module Name: VGA - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity VGA is
    Port ( rst, clk : in STD_LOGIC;
           r, g, b : out STD_LOGIC_vector(3 downto 0);
           roll: in std_logic;
           vsync, hsync : out STD_LOGIC);
end VGA;

architecture Behavioral of VGA is

constant hfp: integer := 16;
constant hbp: integer := 48;
constant hd : integer := 640;
constant hsp: integer := 96;

constant vfp: integer := 10;
constant vbp: integer := 33;
constant vd : integer := 480;
constant vsp: integer := 2;

signal hpos, vpos: integer := 0;

signal clk_div : std_logic := '0';
signal pix_clk : std_logic := '0';

signal roll_sync  : std_logic_vector(2 downto 0) := (others => '0');
signal roll_deb   : std_logic := '0';
signal roll_edge  : std_logic := '0';

signal rolling    : boolean := false;
signal roll_timer : integer range 0 to 25_000_000 := 0;   -- 0.5s roll duration
signal slow_cnt   : integer range 0 to 1_000_000 := 0;    -- delay between number updates

signal lfsr       : std_logic_vector(7 downto 0) := "10101010";  -- 8-bit seed
signal number     : integer range 1 to 6 := 1;

begin

-- Clock dividers
process(clk, rst)
begin
    if rst = '1' then
        clk_div <= '0';
    elsif rising_edge(clk) then
        clk_div <= not clk_div;
    end if;
end process;

process(clk_div, rst)
begin
    if rst = '1' then
        pix_clk <= '0';
    elsif rising_edge(clk_div) then
        pix_clk <= not pix_clk;
    end if;
end process;

-- Position tracking
process(pix_clk)
begin
    if rising_edge(pix_clk) then
        if rst = '1' then
            hpos <= 0;
            vpos <= 0;
        else
            if hpos = (hd + hfp + hbp + hsp) then
                hpos <= 0;
                if vpos = (vd + vfp + vbp + vsp) then
                    vpos <= 0;
                else
                    vpos <= vpos + 1;
                end if;
            else
                hpos <= hpos + 1;
            end if;
        end if;
    end if;
end process;

-- Sync generation
process(pix_clk)
begin
    if rising_edge(pix_clk) then
        hsync <= '1';
        if hpos >= (hd + hfp) and hpos < (hd + hfp + hsp) then
            hsync <= '0';
        end if;
    end if;
end process;

process(pix_clk)
begin
    if rising_edge(pix_clk) then
        vsync <= '1';
        if vpos >= (vd + vfp) and vpos < (vd + vfp + vsp) then
            vsync <= '0';
        end if;
    end if;
end process;

-- Edge detection
process(clk)
begin
    if rising_edge(clk) then
        roll_sync <= roll_sync(1 downto 0) & roll;

        if roll_sync(2) = roll_sync(1) then
            roll_deb <= roll_sync(2);
        end if;

        roll_edge <= roll_deb and not roll_sync(2);
    end if;
end process;

-- RNG + Rolling Logic
process(clk)
    variable lfsr_next_bit : std_logic;
begin
    if rising_edge(clk) then
        if rst = '1' then
            rolling    <= false;
            roll_timer <= 0;
            slow_cnt   <= 0;
            lfsr       <= "10101010"; --170
            number     <= 1;
        else
            -- Trigger new roll
            if roll_edge = '1' and not rolling then
                rolling    <= true;
                roll_timer <= 0;
                slow_cnt   <= 0;
            end if;

            if rolling then
                if roll_timer < 25_000_000 then --0.4 s
                    roll_timer <= roll_timer + 1;

                    if slow_cnt = 1_000_000 then --0.000001
                        -- 8-bit LFSR: taps at bit 8,6,5,4 (x^8 + x^6 + x^5 + x^4 + 1)
                        lfsr_next_bit := lfsr(7) xor lfsr(5) xor lfsr(4) xor lfsr(3);
                        lfsr <= lfsr(6 downto 0) & lfsr_next_bit;

                        -- Map value to 1-6
                        case to_integer(unsigned(lfsr(2 downto 0))) mod 6 is
                            when 0 => number <= 1;
                            when 1 => number <= 2;
                            when 2 => number <= 3;
                            when 3 => number <= 4;
                            when 4 => number <= 5;
                            when others => number <= 6;
                        end case;

                        slow_cnt <= 0;
                    else
                        slow_cnt <= slow_cnt + 1;
                    end if;
                else
                    rolling <= false;
                end if;
            end if;
        end if;
    end if;
end process;

process(hpos, vpos, number)
begin

    r <= "0000"; g <= "0000"; b <= "0000";

    if (hpos < hd and vpos < vd) then
        -- Draw dice white square background
        if (hpos >= 270 and hpos <= 370 and vpos >= 190 and vpos <= 290) then
            r <= "1111"; g <= "1111"; b <= "1111";  -- white background

            -- Draw black dots based on die number
            case number is
                when 1 =>
                    if (hpos >= 318 and hpos <= 322 and vpos >= 238 and vpos <= 242) then
                        r <= "0000"; g <= "0000"; b <= "0000";  -- center
                    end if;
                when 2 =>
                    if ((hpos >= 293 and hpos <= 297 and vpos >= 213 and vpos <= 217) or
                        (hpos >= 343 and hpos <= 347 and vpos >= 263 and vpos <= 267)) then
                        r <= "0000"; g <= "0000"; b <= "0000";  -- top-left and bottom-right
                    end if;
                when 3 =>
                    if ((hpos >= 318 and hpos <= 322 and vpos >= 238 and vpos <= 242) or
                        (hpos >= 293 and hpos <= 297 and vpos >= 213 and vpos <= 217) or
                        (hpos >= 343 and hpos <= 347 and vpos >= 263 and vpos <= 267)) then
                        r <= "0000"; g <= "0000"; b <= "0000";  -- top-left, bottom-right, center
                    end if;
                when 4 =>
                    if ((hpos >= 293 and hpos <= 297 and vpos >= 213 and vpos <= 217) or 
                        (hpos >= 343 and hpos <= 347 and vpos >= 213 and vpos <= 217) or 
                        (hpos >= 293 and hpos <= 297 and vpos >= 263 and vpos <= 267) or  
                        (hpos >= 343 and hpos <= 347 and vpos >= 263 and vpos <= 267)) then
                        r <= "0000"; g <= "0000"; b <= "0000";  -- corners
                    end if;

                when 5 =>
                    if ((hpos >= 293 and hpos <= 297 and vpos >= 213 and vpos <= 217) or 
                        (hpos >= 343 and hpos <= 347 and vpos >= 213 and vpos <= 217) or 
                        (hpos >= 293 and hpos <= 297 and vpos >= 263 and vpos <= 267) or  
                        (hpos >= 343 and hpos <= 347 and vpos >= 263 and vpos <= 267) or
                        (hpos >= 318 and hpos <= 322 and vpos >= 238 and vpos <= 242)) then
                        r <= "0000"; g <= "0000"; b <= "0000";  -- corners + center
                    end if;

                when 6 =>
                    if ((hpos >= 293 and hpos <= 297 and vpos >= 213 and vpos <= 217) or 
                        (hpos >= 343 and hpos <= 347 and vpos >= 213 and vpos <= 217) or 
                        (hpos >= 293 and hpos <= 297 and vpos >= 263 and vpos <= 267) or  
                        (hpos >= 343 and hpos <= 347 and vpos >= 263 and vpos <= 267) or
                        (hpos >= 293 and hpos <= 297 and vpos >= 238 and vpos <= 242) or
                        (hpos >= 343 and hpos <= 347 and vpos >= 238 and vpos <= 242)) then
                        r <= "0000"; g <= "0000"; b <= "0000";  -- 2 vertical rows
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end if;
end process;

end Behavioral;
