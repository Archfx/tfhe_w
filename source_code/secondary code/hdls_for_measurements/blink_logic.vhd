----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 08:14:04
-- Design Name: 
-- Module Name: top - Behavioral
-- Project Name: TFHE FPGA Acceleration
-- Target Devices: Virtex Ultrascale+ VCU128
-- Tool Versions: Vivado 2024.1
-- Description: Derived from the FPGA introduction tutorial. Can be used to check if the
--             FPGA is running.
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.numeric_std.all;

     -- Uncomment the following library declaration if using
     -- arithmetic functions with Signed or Unsigned values
     --use IEEE.NUMERIC_STD.ALL;
     -- Uncomment the following library declaration if instantiating
     -- any Xilinx leaf cells in this code.
     --library UNISIM;
     --use UNISIM.VComponents.all;

entity blink_logic is
     port (
          clk_rx : in  std_logic;
          led_o  : out std_logic_vector
     );
end entity;

architecture Behavioral of blink_logic is
     constant num_cnt_bits : integer := 28;
     signal cnt : unsigned(num_cnt_bits downto 0) := to_unsigned(0, num_cnt_bits + 1);
begin

     led_to_counter_bit_mapping: for i in 0 to led_o'length - 1 generate
          led_o(i) <= cnt(cnt'length - led_o'length + i); -- 2**22 = ca. 4 million -> with 100MHz thats ca. 1/25 of a second, a flimmer that a human can see
     end generate;

     led_ctrl: process (clk_rx)
     begin
          if rising_edge(clk_rx) then
               cnt <= cnt + to_unsigned(1, cnt'length);
               -- overflow handles modulo
          end if;
     end process;

end architecture;
