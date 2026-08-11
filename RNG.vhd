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

entity RandomGen16 is
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        roll     : in  STD_LOGIC;
        randNum  : out INTEGER range 1 to 6
    );
end RandomGen16;

architecture Behavioral of RandomGen16 is
    signal lfsr       : std_logic_vector(3 downto 0) := "1010";
    signal number     : integer range 1 to 6 := 1;
    signal rolling    : boolean := false;
    signal count      : integer range 0 to 7 := 0;
    signal roll_delay : integer := 0;
begin

    process(clk, rst)
    begin
        if rst = '1' then
            lfsr <= "1010";
            number <= 1;
            count <= 0;
            rolling <= false;
        elsif rising_edge(clk) then
            if roll = '1' and not rolling then
                rolling <= true;
                count <= 0;
                roll_delay <= 0;
            elsif rolling then
                if roll_delay = 2000000 then  -- adjust for timing (depends on clock freq)
                    -- Do one shift
                    lfsr <= lfsr(2 downto 0) & (lfsr(3) xor lfsr(2));
                    number <= (to_integer(unsigned(lfsr)) mod 6) + 1;
                    count <= count + 1;
                    roll_delay <= 0;

                    if count = 6 then
                        rolling <= false;
                    end if;
                else
                    roll_delay <= roll_delay + 1;
                end if;
            end if;
        end if;
    end process;

    randNum <= number;
end Behavioral;
