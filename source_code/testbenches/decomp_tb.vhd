----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.09.2024 08:38:39
-- Design Name: 
-- Module Name: decomp_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.NUMERIC_STD.all;
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;
     use work.tb_utils.all;

entity decomp_tb is
     --  Port ( );
end entity;

architecture Behavioral of decomp_tb is

     component decomposition is
          generic (
               throughput           : integer;
               decomposition_length : integer;
               num_LSBs_to_round    : integer;
               bits_per_slice       : integer
          );
          port (
               i_clk       : in  std_ulogic;
               i_sub_polym : in  sub_polynom(0 to throughput - 1);
               o_result    : out synth_uint_vector(0 to throughput * decomposition_length - 1) -- by using this simpler datatype this module only really depends on the generics
          );
     end component;

     constant TIME_DELTA : time := 10 ns;
     constant clk_period : time := TIME_DELTA * 2;

     constant log2_throughput  : integer := log2_ntt_throughput;
     constant next_sample_time : time    := 1 * clk_period;

     constant throughput : integer := 2 ** log2_throughput;

     signal decomp_input_coeff_cnt : idx_int := to_unsigned(0, log2_num_coefficients);

     signal decomp_input_tb : polynom;
     signal decomp_input    : sub_polynom(0 to throughput - 1);
     signal decomp_output   : synth_uint_vector(0 to throughput * decomp_length - 1); -- v4p ignore w-303
     signal clk             : std_ulogic := '1';
     signal finished        : std_ulogic := '0';

     signal zero_polym  : polynom;
     signal test0_input : polynom;

     signal decomp_reset : std_ulogic := '0';

     signal decomp_clk_cnt : integer := 0;
begin
     clk <= not clk after TIME_DELTA when finished /= '1' else '0';

     dut: decomposition
          generic map (
               throughput           => throughput,
               decomposition_length => decomp_length,
               num_LSBs_to_round    => decomp_num_LSBs_to_round,
               bits_per_slice       => log2_decomp_base
          )
          port map (
               i_clk       => clk,
               i_sub_polym => decomp_input,
               o_result    => decomp_output
          );

     process (clk)
     begin
          if rising_edge(clk) then
               if decomp_reset = '1' then
                    decomp_input_coeff_cnt <= to_unsigned(0, decomp_input_coeff_cnt'length);
                    decomp_clk_cnt <= 0;
               else
                    decomp_clk_cnt <= decomp_clk_cnt + 1;

                    decomp_input_coeff_cnt <= decomp_input_coeff_cnt + to_unsigned(throughput, decomp_input_coeff_cnt'length);
                    decomp_input <= decomp_input_tb(to_integer(decomp_input_coeff_cnt) to to_integer(decomp_input_coeff_cnt) + throughput - 1);
               end if;
          end if;
     end process;

     simulation_start_tests: process
          constant const_sig0 : integer := 2;
     begin
          decomp_reset <= '1';

          zero_polym <= get_test_sub_polym(zero_polym'length, 0, 0);
          wait for TIME_DELTA;

          decomp_input_tb <= zero_polym;

          -- prepare signal 0
          test0_input <= get_test_sub_polym(zero_polym'length, const_sig0, 0);
          wait for TIME_DELTA;
          test0_input(0) <= x"FFFFFFFFFFFFFFFF"; -- to check if reduction at the beginning works
          -- make sure that there is a carry that is propagated at the border
          test0_input(1) <= x"0123456789ABCDEF" - to_unsigned(2 ** (decomp_num_LSBs_to_round + 1), unsigned_polym_coefficient_bit_width) + to_unsigned(2 ** (decomp_num_LSBs_to_round), unsigned_polym_coefficient_bit_width);
          -- after rounding this input we expect: x"0123456789AB0000"
          -- so in parts for decomp_length=3, log2_decomp_base=16:
          -- x"89AB" --> leading 1 --> after sign-bit extension: x"189AB", resulting in tfhe_modulos - x"89AB"
          -- x"4567" --> add 1 because of msb previous slice --> x"4568" --> after sign-bit extension: x"04568", resulting in x"4568"
          -- x"0123" --> add 0 because of msb previous slice --> x"0123" --> after sign-bit extension: x"00123", resulting in x"00123"
          wait for TIME_DELTA;

          decomp_reset <= '0';

          -- test 0, constant signal
          decomp_input_tb <= test0_input;
          wait for next_sample_time;

          -- zero out decomp
          decomp_input_tb <= zero_polym;

          wait for 10 * next_sample_time;

          report "Check correctness manually!" severity warning;
          finished <= '1';

          wait; -- without wait this process executes in a loop
     end process;

end architecture;
