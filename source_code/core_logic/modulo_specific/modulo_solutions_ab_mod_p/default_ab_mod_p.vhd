----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: default_ab_mod_p
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: computes a*b mod p. Does create weird synthesis results. Only use this for testbenches.
--              because of the ntt background we write a=i_num and b=i_twiddle_factor
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

     -- this computes: A*B mod p

entity default_ab_mod_p is
     generic (
          p : synthesiseable_uint
     );
     port (
          i_clk            : in  std_ulogic;
          i_numA           : in  synthesiseable_uint;
          i_twiddle_factor : in  synthesiseable_uint;
          o_result         : out synthesiseable_uint
     );
end entity;

architecture Behavioral of default_ab_mod_p is

     component big_mult is
          port (
               i_clk  : in  std_ulogic;
               i_num0 : in  synthesiseable_uint;
               i_num1 : in  synthesiseable_uint;
               o_res  : out synthesiseable_udouble
          );
     end component;

     signal temp_a_b : synthesiseable_udouble;
begin
     process (i_clk)
     begin
          if rising_edge(i_clk) then
               o_result <= to_synth_uint(temp_a_b mod to_synth_udouble(p));
          end if;
     end process;

     big_mult_module: big_mult
          port map (
               i_clk  => i_clk,
               i_num0 => i_numA,
               i_num1 => i_twiddle_factor,
               o_res  => temp_a_b
          );

end architecture;
