----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: tfhe_utils - package
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Ciphertext and helper types for TFHE calculations.
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
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.tfhe_constants.all;
     use work.ntt_utils.all;
     use work.math_utils.all;

package tfhe_utils is

     type ciphertext_LWE is record
          a : synth_uint_vector(0 to k_lwe - 1);
          b : synthesiseable_uint;
     end record;

     type ciphertext_RLWE is record
          a : lwe_n_a_dtype(0 to k - 1);
          b : polynom;
     end record;

     type ciphertext_somewhat_LWE is record
          a : lwe_n_a_dtype(0 to k - 1);
          b : synthesiseable_uint;
     end record;

     -- L_ints are used by the decomposition. They save resources as the coefficients in the decomposition result
     -- have only log2_decomp_base+1 bits and not the default unsigned_polym_coefficient_bit_width
     subtype synthesisable_L_int is signed(0 to log2_decomp_base - 1 + 1); -- +1 for the sign bit
     type synth_L_int_vector is array (natural range <>) of synthesisable_L_int;

     function get_test_BSKi(
          start_num : integer;
          step_size : integer
     ) return lwe_n_a_dtype;

     function init_mult_LUT return polynom;

     constant zero_polynom : polynom := get_test_polym(0, 0, false, pbs_throughput, ntt_num_blocks_per_polym);

     constant pbs_lookuptable_for_mult : polynom := to_ntt_mixed_format(init_mult_LUT, ntt_num_blocks_per_polym, pbs_throughput);
     constant pbs_default_lookuptable  : polynom := get_test_polym(0, 1, true, pbs_throughput, ntt_num_blocks_per_polym);

end package;

package body tfhe_utils is

     function init_mult_LUT
          return polynom is
          variable lut : polynom;
          constant precision : integer := integer(floor(sqrt(real(get_min(unsigned_polym_coefficient_bit_width, num_coefficients)))));
     begin
          for i in 0 to precision - 1 loop
               for j in 0 to precision - 1 loop
                    lut(i * precision + j) := to_synth_uint(i * j);
               end loop;
          end loop;
          return lut;
     end function;

     function get_test_BSKi(
               start_num : integer;
               step_size : integer
          ) return lwe_n_a_dtype is
          variable res : lwe_n_a_dtype(0 to num_polyms_per_rlwe_ciphertext * decomp_length - 1);
     begin
          for i in 0 to res'length - 1 loop
               res(i) := get_test_polym(i * start_num, i * step_size, true, pbs_throughput, ntt_num_blocks_per_polym);
          end loop;
          return res;
     end function;

end package body;
