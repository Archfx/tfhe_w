----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_mod
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: computes A mod p. Will chose the correct modulo solution according to the configuration.
--             Does not use precomputed values, so in case of barett with a precomputed value call
--             ntt_mult_mod_twiddle instead.
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

entity a_mod_p is
     generic (
          p : synthesiseable_uint
     );
     port (
          i_clk     : in  std_ulogic;
          i_num     : in  synthesiseable_udouble;
          o_mod_res : out synthesiseable_uint
     );
end entity;

architecture Behavioral of a_mod_p is

     component modulo_default is
          generic (
               p : synthesiseable_uint
          );
          port (
               i_clk    : in  std_ulogic;
               i_num    : in  synthesiseable_udouble;
               o_result : out synthesiseable_uint
          );
     end component;

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

begin

     default_modulo: if ntt_modulo_solution = ntt_modulo_solution_default generate
          a_mod_p: modulo_default
               generic map (
                    p => p
               )
               port map (
                    i_clk    => i_clk,
                    i_num    => i_num,
                    o_result => o_mod_res
               );
     end generate;

     solinas_modulo: if ntt_modulo_solution = ntt_modulo_solution_solinas generate
          a_mod_p: modulo_solinas
               generic map (
                    p => p
               )
               port map (
                    i_clk    => i_clk,
                    i_num    => i_num,
                    o_result => o_mod_res
               );
     end generate;

end architecture;
