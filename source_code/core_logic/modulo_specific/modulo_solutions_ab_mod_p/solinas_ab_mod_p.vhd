----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: solinas_ab_mod_p
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: computes a*b mod 0xFFFFFFFF00000001
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

     -- this computes: A*B mod 0xFFFFFFFF00000001
     -- assumption: A,B and 0xFFFFFFFF00000001 are presented as 64-bit numbers

entity solinas_ab_mod_p is
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

architecture Behavioral of solinas_ab_mod_p is
     signal temp_a_b : synthesiseable_udouble;

     component modulo_solinas is
          generic (
               p : synthesiseable_uint
          );
          port (
               i_clk    : in  std_ulogic;
               i_num    : in  synthesiseable_udouble;
               o_result : out synthesiseable_uint
          );
     end component;

     component big_mult is
          port (
               i_clk  : in  std_ulogic;
               i_num0 : in  synthesiseable_uint;
               i_num1 : in  synthesiseable_uint;
               o_res  : out synthesiseable_udouble
          );
     end component;
begin

     big_mult_module: big_mult
          port map (
               i_clk  => i_clk,
               i_num0 => i_numA,
               i_num1 => i_twiddle_factor,
               o_res  => temp_a_b
          );

     modulo_block: modulo_solinas
          generic map (
               p => p
          )
          port map (
               i_clk    => i_clk,
               i_num    => temp_a_b,
               o_result => o_result
          );

end architecture;
