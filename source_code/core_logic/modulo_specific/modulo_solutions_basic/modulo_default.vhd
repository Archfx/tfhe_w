----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: modulo_default
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: computes i_num mod ntt_prime using the native way, which is supposedly
--             not synthesisable and produces really weird synthesis results if you try.
--             However, we use this for faster simulations and as a check for if the
--             other modulo modules produce the correct result in simulations.
-- Dependencies: see imports
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.numeric_std.all;
library work;
     use work.datatypes_utils.all;

entity modulo_default is
     generic (
          p : synthesiseable_uint
     );
     port (
          i_clk    : in  std_ulogic;
          i_num    : in  synthesiseable_udouble;
          o_result : out synthesiseable_uint
     );
end entity;

architecture Behavioral of modulo_default is
begin
     process (i_clk)
     begin
          if rising_edge(i_clk) then
               o_result <= to_synth_uint(to_synth_double(i_num) mod to_synth_double(to_synth_int(p)));
          end if;
     end process;

end architecture;
