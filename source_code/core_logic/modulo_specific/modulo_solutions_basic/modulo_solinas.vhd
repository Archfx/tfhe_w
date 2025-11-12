----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: modulo_solinas
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Computes i_num mod 0xFFFFFFFF00000001
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

     -- this computes: (a mod ntt_prime) via the solution presented in the Number Theoretic Transform (NTT) FPGA
     -- Accelerator paper by Austin Hartshorn et al. (HLW)
     -- However, the HLW paper has a mistake in their diagram: it does a substraction in stage 1, but there should be an addition
     -- the mistake was verified by going to the original source, Emmert et al.
     -- and we work between 0 and p, so we need to consider the case a != 0 and b,c,d=0, in which case we need to add p
     -- assumption: prime is solinas-prime for 64-bit numbers: 0xFFFFFFFF00000001

entity modulo_solinas is
     generic (
          p : synthesiseable_uint
     );
     port (
          i_clk    : in  std_ulogic;
          i_num    : in  synthesiseable_udouble;
          o_result : out synthesiseable_uint
     );
end entity;

architecture Behavioral of modulo_solinas is

     -- this modulo solution can only handle 128-bit inputs

     -- extra bit for the sign
     signal a : unsigned(0 to 32 - 1);
     signal b : unsigned(0 to 32 - 1);
     signal c : unsigned(0 to 32 - 1);
     signal d : unsigned(0 to 32 - 1);
     type sub_int_wait_register is array (natural range <>) of signed(0 to a'length + 2 - 1); -- +1 for sign, +1 for underflowavoidance
     type sub_uint_wait_register is array (natural range <>) of unsigned(0 to a'length + 1 - 1); -- +1 for underflowavoidance
     signal temp_d_a_b       : sub_int_wait_register(0 to clks_per_34_bit_add - 1); --  is between -2*(2^32 -1) and +(2^32 -1)
     signal d_expanded       : signed(0 to temp_d_a_b(0)'length - 1);
     signal temp_b_c         : sub_uint_wait_register(0 to clks_per_34_bit_add - 1);
     signal temp_b_c_shifted : synthesiseable_uint_extended;
     signal temp_res         : wait_registers_int_extended(0 to clks_per_64_bit_add - 1);
     signal reduce_val       : synth_uint_vector(0 to clks_per_64_bit_add - 1);
     signal temp_res_cropped : synthesiseable_uint;
     -- signal temp_res_cropped_plus_p : synthesiseable_uint;
     -- signal temp_res_cropped_minus_p : synthesiseable_uint;
     -- signal temp_res_cropped_original : synthesiseable_int_extended;

begin

     add_34_buffer_flow: if clks_per_34_bit_add > 1 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    temp_d_a_b(1 to temp_d_a_b'length - 1) <= temp_d_a_b(0 to temp_d_a_b'length - 2);
                    temp_b_c_shifted(1 to temp_b_c_shifted'length - 1) <= temp_b_c_shifted(0 to temp_b_c_shifted'length - 2);
               end if;
          end process;
     end generate;

     add_64_buffer_flow: if clks_per_64_bit_add > 1 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    temp_res(1 to temp_res'length - 1) <= temp_res(0 to temp_res'length - 2);
                    reduce_val(1 to reduce_val'length - 1) <= reduce_val(0 to reduce_val'length - 2);
               end if;
          end process;
     end generate;

     d_expanded(0)                          <= '0';             -- sign bit
     d_expanded(1 to d_expanded'length - 1) <= signed('0' & d); -- carry placeholder

     temp_b_c_shifted(0 to temp_b_c(0)'length - 1) <= temp_b_c(temp_b_c'length - 1)(0 to temp_b_c(0)'length - 1);
     -- fill with zeros
     temp_b_c_shifted(temp_b_c(0)'length to temp_b_c_shifted'length - 1) <= to_unsigned(0, temp_b_c_shifted'length - temp_b_c(0)'length);

     temp_res_cropped <= unsigned(temp_res(temp_res'length - 1)(temp_res(0)'length - reduce_val(0)'length to temp_res(0)'length - 1));

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               -- stage 0
               temp_d_a_b(0) <= (d_expanded - signed('0' & a)) - signed('0' & b);
               temp_b_c(0) <= ('0' & b) + c;

               -- stage 1
               temp_res(0) <= signed('0' & temp_b_c_shifted) + temp_d_a_b(temp_d_a_b'length - 1); -- cannot have a carry but 0 for the sign

               -- stage 2
               if temp_res(temp_res'length - 1) < to_synth_int_extended(to_synth_uint(0)) then
                    reduce_val(0) <= temp_res_cropped + p;
               elsif temp_res(temp_res'length - 1) > signed('0' & p) then
                    reduce_val(0) <= temp_res_cropped - p;
               else
                    reduce_val(0) <= temp_res_cropped;
               end if;

               -- stage 3
               o_result <= reduce_val(reduce_val'length - 1);

               -- -- stage 2
               -- temp_res_cropped_plus_p <= temp_res_cropped + p;
               -- temp_res_cropped_minus_p <= temp_res_cropped - p;
               -- temp_res_cropped_original <= temp_res(temp_res'length - 1);
               -- -- stage 3
               -- if temp_res_cropped_original < to_synth_int_extended(to_synth_uint(0)) then
               --      o_result <= temp_res_cropped_plus_p;
               -- elsif temp_res_cropped_original > signed('0' & p) then
               --      o_result <= temp_res_cropped_minus_p;
               -- else
               --      o_result <= to_synth_uint(temp_res_cropped_original);
               -- end if;
          end if;
     end process;

     a <= i_num(0 to i_num'length - 96 - 1);
     b <= i_num(i_num'length - 96 to i_num'length - 64 - 1);
     c <= i_num(i_num'length - 64 to i_num'length - 32 - 1);
     d <= i_num(i_num'length - 32 to i_num'length - 1);

end architecture;
