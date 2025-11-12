----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: mult_reduce
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Does mult including modulo reduction for cases where there are no precomputed support values to do this.
--             Use ab_mod_p modulo solutions when one operand is known in advance (e.g. Barett reduction)
-- Dependencies: see imports
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.NUMERIC_STD.all;
     use IEEE.math_real.all;
library work;
     use work.datatypes_utils.all;
     use work.constants_utils.all;

entity ab_mod_p_plain is
     generic (
          p : synthesiseable_uint
     );
     port (
          i_clk    : in  std_ulogic;
          i_num0   : in  synthesiseable_uint;
          i_num1   : in  synthesiseable_uint;
          o_result : out synthesiseable_uint
     );
end entity;

architecture Behavioral of ab_mod_p_plain is

     component a_mod_p is
          generic (
               p : synthesiseable_uint
          );
          port (
               i_clk     : in  std_ulogic;
               i_num     : in  synthesiseable_udouble;
               o_mod_res : out synthesiseable_uint
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

     signal temp_res : synthesiseable_udouble;

begin

     big_mult_module: big_mult
          port map (
               i_clk  => i_clk,
               i_num0 => i_num0,
               i_num1 => i_num1,
               o_res  => temp_res
          );
     mod_module: a_mod_p
          generic map (
               p => p
          )
          port map (
               i_clk     => i_clk,
               i_num     => temp_res,
               o_mod_res => o_result
          );

end architecture;
