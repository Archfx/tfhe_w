----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: big_mult
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: outsourcing of bigger-than-DSP-size arithmetic operation
--             with additional registers, so that retiming can happen
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

entity big_mult is
     port (
          i_clk  : in  std_ulogic;
          i_num0 : in  synthesiseable_uint;
          i_num1 : in  synthesiseable_uint;
          o_res  : out synthesiseable_udouble
     );
end entity;

architecture Behavioral of big_mult is

     component default_mult is
          generic (
               base_len            : integer;
               dsp_retiming_length : integer
          );
          port (
               i_clk  : in  std_ulogic;
               i_num0 : in  unsigned(0 to base_len - 1);
               i_num1 : in  unsigned(0 to base_len - 1);
               o_res  : out unsigned(0 to 2 * base_len - 1)
          );
     end component;

     component karazuba_mult is
          generic (
               base_len            : integer;
               dsp_retiming_length : integer
          );
          port (
               i_clk  : in  std_ulogic;
               i_num0 : in  synthesiseable_uint;
               i_num1 : in  synthesiseable_uint;
               o_res  : out synthesiseable_udouble
          );
     end component;

begin

     karazuba: if use_karazuba generate
          mult_karazuba: karazuba_mult
               generic map (
                    base_len            => 32,
                    dsp_retiming_length => dsp_level_retiming_registers
               )
               port map (
                    i_clk  => i_clk,
                    i_num0 => i_num0,
                    i_num1 => i_num1,
                    o_res  => o_res
               );
     end generate;

     non_karazuba: if not use_karazuba generate
          mult_default: default_mult
               generic map (
                    base_len            => 64,
                    dsp_retiming_length => dsp_level_retiming_registers
               )
               port map (
                    i_clk  => i_clk,
                    i_num0 => i_num0,
                    i_num1 => i_num1,
                    o_res  => o_res
               );
     end generate;

end architecture;
