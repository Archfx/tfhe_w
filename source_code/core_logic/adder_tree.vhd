----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: adder_tree
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Does sum(i_vector) including modulo reduction. Pads the input to the next biggest power-of-two-size.
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
     use work.math_utils.all;

entity adder_tree is
     generic (
          vector_length : integer;
          modulus       : synthesiseable_uint
     );
     port (
          i_clk    : in  std_ulogic;
          i_vector : in  synth_uint_vector(0 to vector_length - 1);
          o_result : out synthesiseable_uint
     );
end entity;

architecture Behavioral of adder_tree is

     component add_reduce is
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
     end component;

     constant num_stages : integer := integer(get_bit_length(i_vector'length - 1));

     signal power_of_two_input : synth_uint_vector(0 to 2 ** num_stages - 1);
     signal inout_array        : synth_uint_vector(0 to 2 * (2 ** num_stages) - 1 - 1); -- another -1 since adder tree has 2*input_size-1 many in/outputs

begin

     o_result <= inout_array(inout_array'length - 1);
     input_mapping: for i in 0 to i_vector'length - 1 generate
          power_of_two_input(i) <= i_vector(i);
     end generate;
     input_filler: for i in i_vector'length to power_of_two_input'length - 1 generate
          power_of_two_input(i) <= to_synth_uint(0);
     end generate;
     in_map: for i in 0 to power_of_two_input'length - 1 generate
          inout_array(i) <= power_of_two_input(i);
     end generate;

     inout_map: if num_stages > 0 generate
          -- adder tree stages have differently sized inputs/outputs from stage to stage
          -- however, vhdl does not allow arrays with differently sized elements
          -- so we do a trick: we concatenate all stages inputs and outputs into one array, the inout_array
          -- and then we do the mapping: the first half of this array is for the first stage, the half of what is left for the second, ...
          -- the outputs are written as the inputs of the next stage
          stage_map: for stage_idx in 0 to num_stages - 1 generate
               coeff_map: for coeff_idx in 0 to power_of_two_input'length / (2 ** (stage_idx + 1)) - 1 generate
                    vector_add: add_reduce
                         generic map (
                              substraction => false,
                              modulus      => modulus
                         )
                         port map (
                              i_clk    => i_clk,
                              -- add the values that are next to each other to ease congestion
                              i_num0   => inout_array(inout_array'length - 2 ** (num_stages - stage_idx) - 2 * coeff_idx),
                              i_num1   => inout_array(inout_array'length - 2 ** (num_stages - stage_idx) - 2 * coeff_idx - 1),
                              o_result => inout_array(inout_array'length - 2 ** (num_stages - stage_idx) + 1 + coeff_idx)
                         );
               end generate;
          end generate;
     end generate;

end architecture;
