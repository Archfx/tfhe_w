----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: add_reduce
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Does add/sub including an easy modulo reduction, if wanted
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

entity add_reduce is
     generic (
          substraction : boolean;
          modulus      : synthesiseable_uint
     );
     port (
          i_clk    : in  std_ulogic;
          i_num0   : in  synthesiseable_uint;
          i_num1   : in  synthesiseable_uint;
          o_result : out synthesiseable_uint
     );
end entity;

architecture Behavioral of add_reduce is

     component big_add is
          generic (
               substraction : boolean := false
          );
          port (
               i_clk  : in  std_ulogic;
               i_num0 : in  synthesiseable_int;
               i_num1 : in  synthesiseable_int;
               o_res  : out synthesiseable_int_extended
          );
     end component;

     component easy_reduction is
          generic (
               modulus         : synthesiseable_uint;
               can_be_negative : boolean
          );
          port (
               i_clk     : in  std_ulogic;
               i_num     : in  synthesiseable_int_extended;
               o_mod_res : out synthesiseable_uint
          );
     end component;

     signal temp_res      : synthesiseable_int_extended;
     signal num0_extended : synthesiseable_int;
     signal num1_extended : synthesiseable_int;

begin

     num0_extended <= signed('0' & i_num0);
     num1_extended <= signed('0' & i_num1);

     big_add_module: big_add
          generic map (
               substraction => substraction
          )
          port map (
               i_clk  => i_clk,
               i_num0 => num0_extended,
               i_num1 => num1_extended,
               o_res  => temp_res
          );
     easy_red_module: easy_reduction
          generic map (
               modulus         => modulus,
               can_be_negative => substraction
          )
          port map (
               i_clk     => i_clk,
               i_num     => temp_res,
               o_mod_res => o_result
          );

end architecture;
