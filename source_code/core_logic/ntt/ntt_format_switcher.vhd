----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_format_switcher
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: switches a normal-ordered input into the NTT-mixed expected by the first stage of the sequential NTT.
--             Can also take the INTT-mixed output and bring it back to normal order.
--             This module uses a just-in-time buffer scheme, such that just 1,25 polynomials must be buffered in each case.
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
     use work.math_utils.all;

entity ntt_format_switcher is
     generic (
          input_size : integer; -- must be a multiple of throughput
          throughput : integer; -- must be a power of 2
          invers     : boolean
     );
     port (
          i_clk                   : in  std_ulogic;
          i_reset                 : in  std_ulogic;
          i_previous_stage_output : in  sub_polynom(0 to throughput - 1);
          o_next_stage_input      : out sub_polynom(0 to throughput - 1);
          o_next_stage_reset      : out std_ulogic
     );
end entity;

architecture Behavioral of ntt_format_switcher is

     constant cnt_size : integer := get_bit_length(input_size - 1);

     constant half_throughput          : unsigned(0 to cnt_size - 1) := to_unsigned(throughput / 2, cnt_size);
     constant half_input_size          : unsigned(0 to cnt_size - 1) := to_unsigned(input_size / 2, cnt_size);
     constant quarter_input_size       : unsigned(0 to cnt_size - 1) := to_unsigned(input_size / 4, cnt_size);
     constant three_quarter_input_size : unsigned(0 to cnt_size - 1) := to_unsigned(input_size * 3 / 4, cnt_size);
     signal internal_input       : sub_polynom(0 to input_size - 1);
     signal input_quarter_buffer : sub_polynom(0 to to_integer(quarter_input_size) - 1);
     signal start_outputting     : std_ulogic;
     signal out_not_ready        : std_ulogic;
     -- for ntt output is half the size of the input. Opposite is true for the intt.
     -- ntt needs to accumulate just half of the previous stages output as input for the next stage. So we need to half it.
     -- intt needs to accumulate double of the previous stages output as input for the next stage. input_size contains the double value, so we need to half it.
     constant in_coeff_length  : integer := (boolean'pos(invers) * (cnt_size - 1) + boolean'pos(not invers) * cnt_size);
     constant out_coeff_length : integer := (boolean'pos(invers) * cnt_size + boolean'pos(not invers) * (cnt_size - 1));
     signal in_coeff_cnt  : unsigned(0 to in_coeff_length - 1)  := to_unsigned(0, in_coeff_length);
     signal out_coeff_cnt : unsigned(0 to out_coeff_length - 1) := to_unsigned(0, out_coeff_length);

     constant special_case                 : boolean := throughput > input_quarter_buffer'length;
     constant start_outputting_trigger_val : integer := boolean'pos(not invers) * to_integer(half_input_size) + boolean'pos(invers) * (boolean'pos(not special_case) * to_integer(quarter_input_size + quarter_input_size / 2 - half_throughput) + boolean'pos(special_case) * to_integer(quarter_input_size));
     -- constant num_quarter_blocks           : integer := input_size / (throughput / (boolean'pos(not invers)*1 + boolean'pos(invers)*2)) / 4;

begin

     o_next_stage_reset <= out_not_ready;

     ntt_normal_to_mixed_logic: if not invers generate
          -- input handling
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    if i_reset = '1' then
                         in_coeff_cnt <= to_unsigned(0, in_coeff_cnt'length);
                         start_outputting <= '0';
                    else
                         in_coeff_cnt <= in_coeff_cnt + to_unsigned(throughput, in_coeff_cnt'length);
                         -- if counter is about to overflow write the input to the other half of internal_input
                         if in_coeff_cnt = to_unsigned(start_outputting_trigger_val, cnt_size) then
                              start_outputting <= '1';
                              -- we have gathered enough blocks to produce an output
                              -- however, the second quarter of internal input will be overwritten by our input before it can be processed so we need to buffer it
                              input_quarter_buffer <= internal_input(to_integer(quarter_input_size) to to_integer(half_input_size) - 1);
                         end if;

                         -- fill internal buffer normal, block by block
                         for i in 0 to throughput - 1 loop
                              internal_input(i + to_integer(in_coeff_cnt)) <= i_previous_stage_output(i);
                         end loop;
                    end if;
               end if;
          end process;

          -- output handling
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    if i_reset = '1' then
                         out_coeff_cnt <= to_unsigned(0, out_coeff_cnt'length);
                         out_not_ready <= '1';
                    else
                         -- start processing when more than half of your blocks are ready
                         if start_outputting = '1' then
                              out_not_ready <= '0';

                              out_coeff_cnt <= out_coeff_cnt + resize(half_throughput, out_coeff_cnt'length);

                              if out_coeff_cnt >= quarter_input_size then
                                   -- take first half of the values from buffer
                                   for i in 0 to throughput / 2 - 1 loop
                                        o_next_stage_input(i) <= input_quarter_buffer(to_integer(out_coeff_cnt - quarter_input_size) + i);
                                   end loop;
                              else
                                   for i in 0 to throughput / 2 - 1 loop
                                        o_next_stage_input(i) <= internal_input(to_integer(out_coeff_cnt) + i);
                                   end loop;
                              end if;
                              -- other half
                              for i in 0 to throughput / 2 - 1 loop
                                   o_next_stage_input(throughput / 2 + i) <= internal_input(to_integer(out_coeff_cnt + half_input_size) + i);
                              end loop;
                         end if;
                    end if;
               end if;
          end process;
     end generate;

     intt_mixed_to_normal_logic: if invers generate

          normal_case: if not special_case generate
               -- input handling
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if i_reset = '1' then
                              in_coeff_cnt <= to_unsigned(0, in_coeff_cnt'length);
                              start_outputting <= '0';
                         else
                              in_coeff_cnt <= in_coeff_cnt + resize(half_throughput, in_coeff_cnt'length);
                              -- if counter is about to overflow write the input to the other half of internal_input
                              if in_coeff_cnt = to_unsigned(start_outputting_trigger_val, cnt_size) then
                                   -- we have gathered enough blocks to produce an output
                                   -- the third quarter of internal input will be overwritten by our input before it can be processed so we need to buffer it
                                   input_quarter_buffer <= internal_input(to_integer(half_input_size) to to_integer(half_input_size + quarter_input_size) - 1);
                                   start_outputting <= '1';
                              end if;

                              for i in 0 to throughput / 2 - 1 loop
                                   internal_input(to_integer(in_coeff_cnt) + i) <= i_previous_stage_output(i);
                                   internal_input(to_integer(in_coeff_cnt + half_input_size) + i) <= i_previous_stage_output(to_integer(half_throughput) + i);
                              end loop;
                         end if;
                    end if;
               end process;

               -- output handling
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if i_reset = '1' then
                              out_coeff_cnt <= to_unsigned(0, out_coeff_cnt'length);
                              out_not_ready <= '1';
                         else
                              if start_outputting = '1' then
                                   out_not_ready <= '0';

                                   out_coeff_cnt <= out_coeff_cnt + to_unsigned(throughput, out_coeff_cnt'length);

                                   if out_coeff_cnt >= half_input_size and out_coeff_cnt < three_quarter_input_size then
                                        for i in 0 to throughput - 1 loop
                                             o_next_stage_input(i) <= input_quarter_buffer(to_integer(out_coeff_cnt - half_input_size) + i);
                                        end loop;
                                   else
                                        for i in 0 to throughput - 1 loop
                                             o_next_stage_input(i) <= internal_input(to_integer(out_coeff_cnt) + i);
                                        end loop;
                                   end if;
                              end if;
                         end if;
                    end if;
               end process;
          end generate;

          -- special case: if n=2*throughput then the format switch does not do anything
          -- to keep the clock cycle delay we do it like before but now quarter_buffer works together with internal_input
          special_case_inst: if special_case generate
               -- input handling
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if i_reset = '1' then
                              in_coeff_cnt <= to_unsigned(0, in_coeff_cnt'length);
                              start_outputting <= '0';
                         else
                              in_coeff_cnt <= in_coeff_cnt + resize(half_throughput, in_coeff_cnt'length);
                              -- if counter is about to overflow write the input to the other half of internal_input
                              if in_coeff_cnt = to_unsigned(start_outputting_trigger_val, cnt_size) then
                                   -- we have gathered enough blocks to produce an output
                                   -- the third quarter of internal input will be overwritten by our input before it can be processed so we need to buffer it
                                   input_quarter_buffer <= internal_input(to_integer(half_input_size) to to_integer(half_input_size + quarter_input_size) - 1);
                                   start_outputting <= '1';
                              end if;

                              for i in 0 to throughput / 2 - 1 loop
                                   internal_input(to_integer(in_coeff_cnt) + i) <= i_previous_stage_output(i);
                                   internal_input(to_integer(in_coeff_cnt + half_input_size) + i) <= i_previous_stage_output(to_integer(half_throughput) + i);
                              end loop;
                         end if;
                    end if;
               end process;

               -- output handling
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if i_reset = '1' then
                              out_coeff_cnt <= to_unsigned(0, out_coeff_cnt'length);
                              out_not_ready <= '1';
                         else
                              if start_outputting = '1' then
                                   out_not_ready <= '0';

                                   out_coeff_cnt <= out_coeff_cnt + to_unsigned(throughput, out_coeff_cnt'length);

                                   if out_coeff_cnt >= half_input_size and out_coeff_cnt < three_quarter_input_size then
                                        for i in 0 to input_quarter_buffer'length - 1 loop
                                             o_next_stage_input(i) <= input_quarter_buffer(to_integer(out_coeff_cnt - half_input_size) + i);
                                        end loop;
                                        for i in input_quarter_buffer'length to throughput - 1 loop
                                             o_next_stage_input(i) <= internal_input(to_integer(out_coeff_cnt) + i);
                                        end loop;
                                   else
                                        for i in 0 to throughput - 1 loop
                                             o_next_stage_input(i) <= internal_input(to_integer(out_coeff_cnt) + i);
                                        end loop;
                                   end if;
                              end if;
                         end if;
                    end if;
               end process;
          end generate;
     end generate;

end architecture;
