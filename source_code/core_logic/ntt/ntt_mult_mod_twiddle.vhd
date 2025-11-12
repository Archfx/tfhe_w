----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_mult_mod_twiddle
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This module handels computations of the form a*b mod p where b is a twiddle factor.
--             This module is needed because the calculation can be accelerated with precomputed values,
--             which we only have for constants like the twiddle factors.
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
     use work.constants_utils.all;
     use work.datatypes_utils.all;

entity ntt_mult_mod_twiddle is
     generic (
          prime : synthesiseable_uint
     );
     port (
          i_clk            : in  std_ulogic;
          i_a_part         : in  synthesiseable_uint;
          i_twiddle_factor : in  synthesiseable_uint;
          o_mod_res        : out synthesiseable_uint
     );
end entity;

architecture Behavioral of ntt_mult_mod_twiddle is

     component default_ab_mod_p is
          generic (
               p : synthesiseable_uint
          );
          port (
               i_clk            : in  std_ulogic;
               i_numA           : in  synthesiseable_uint;
               i_twiddle_factor : in  synthesiseable_uint;
               o_result         : out synthesiseable_uint
          );
     end component;

     component solinas_ab_mod_p is
          generic (
               p : synthesiseable_uint
          );
          port (
               i_clk            : in  std_ulogic;
               i_numA           : in  synthesiseable_uint;
               i_twiddle_factor : in  synthesiseable_uint;
               o_result         : out synthesiseable_uint
          );
     end component;

begin

     default_modulo: if ntt_modulo_solution = ntt_modulo_solution_default generate
          ab_mod_p: default_ab_mod_p
               generic map (
                    p => prime
               )
               port map (
                    i_clk            => i_clk,
                    i_numA           => i_a_part,
                    i_twiddle_factor => i_twiddle_factor,
                    o_result         => o_mod_res
               );
     end generate;

     solinas_modulo: if ntt_modulo_solution = ntt_modulo_solution_solinas generate
          ab_mod_p: solinas_ab_mod_p
               generic map (
                    p => prime
               )
               port map (
                    i_clk            => i_clk,
                    i_numA           => i_a_part,
                    i_twiddle_factor => i_twiddle_factor,
                    o_result         => o_mod_res
               );
     end generate;

end architecture;
