----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: easy_reduction
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: checks if value out of bound and substracts / adds a single time accordingly
--              Call this module after additions and substractions to keep the values in Zq.
--              Call ntt_mod or ntt_mult_mod_twiddle in case you did a multiplication before
--              and want the result in Zq.
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
     use work.constants_utils.all;

entity easy_reduction is
     generic (
          modulus         : synthesiseable_uint;
          can_be_negative : boolean -- meaning: the number can be negative, so that you must add modulus instead of substracting it
     );
     port (
          i_clk     : in  std_ulogic;
          i_num     : in  synthesiseable_int_extended;
          o_mod_res : out synthesiseable_uint
     );
end entity;

architecture Behavioral of easy_reduction is

     signal reduced_res : synthesiseable_uint;
     signal num_buf     : wait_registers_int_extended(0 to clks_per_64_bit_add - 1);

     signal reg_chain : wait_registers_uint(0 to (clks_per_64_bit_add-1*boolean'pos(big_add_in_buf)) - 1);
     signal num0_buf: synthesiseable_uint;

begin

     num_buf_flow: if num_buf'length > 1 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    num_buf(1 to num_buf'length - 1) <= num_buf(0 to num_buf'length - 2);
               end if;
          end process;
     end generate;

     case_minus: if not can_be_negative generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    -- stage 0
                    -- big_add, result: reduced_res
                    num_buf(0) <= i_num;

                    -- stage 1
                    if num_buf(num_buf'length - 1) >= to_synth_int_extended(modulus) then
                         o_mod_res <= reduced_res;
                    else
                         o_mod_res <= to_synth_uint(num_buf(num_buf'length - 1));
                    end if;
               end if;
          end process;
     end generate;

     case_plus: if can_be_negative generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    -- stage 0
                    -- big_add, result: reduced_res
                    num_buf(0) <= i_num;

                    -- stage 1
                    if num_buf(num_buf'length - 1) < to_synth_int_extended(to_synth_uint(0)) then
                         o_mod_res <= reduced_res;
                    else
                         o_mod_res <= to_synth_uint(num_buf(num_buf'length - 1));
                    end if;
               end if;
          end process;
     end generate;

     -- the actual addition / subtraction     
     no_in_reg: if not big_add_in_buf generate
          num0_buf <= to_synth_uint(i_num);
     end generate;

     in_reg: if big_add_in_buf generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    num0_buf <= to_synth_uint(i_num);
               end if;
          end process;
     end generate;

     add: if can_be_negative generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    reg_chain(0) <= num0_buf + modulus;
               end if;
          end process;
     end generate;

     sub: if not can_be_negative generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    reg_chain(0) <= num0_buf - modulus;
               end if;
          end process;
     end generate;

     reg_flow: if reg_chain'length > 1 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    reg_chain(1 to reg_chain'length - 1) <= reg_chain(0 to reg_chain'length - 2);
               end if;
          end process;
     end generate;

     reduced_res <= reg_chain(reg_chain'length - 1);

end architecture;
