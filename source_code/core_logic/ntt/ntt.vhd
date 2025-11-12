----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: fuses together multiple single stages and a fully parallel stage to form a sequential ntt or intt.
--             There is a stage-logic module before each stage but the first that handles the stages' input buffer.
--             Early reset: Reset must be given ram_retiming_latency clock tics before i_sub_polym is valid to prepare the twiddles!
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
     use work.datatypes_utils.all;
     use work.constants_utils.all;
     use work.ntt_utils.all;

entity ntt is
     generic (
          throughput                : integer;
          ntt_params                : ntt_params_with_precomputed_values;
          invers                    : boolean;
          intt_no_final_reduction   : boolean;
          no_first_last_stage_logic : boolean -- if true no format switches
     );
     port (
          i_clk               : in  std_ulogic;
          i_reset             : in  std_ulogic; -- reset must be 1 for at least ntt_ram_retiming_latency tics to set up the twiddle factors!
          i_sub_polym         : in  sub_polynom(0 to throughput - 1);
          o_result            : out sub_polynom(0 to throughput - 1);
          o_next_module_reset : out std_ulogic
     );
end entity;

architecture Behavioral of ntt is

     component ntt_fully_parallel_stage_base is
          generic (
               prime                 : synthesiseable_uint;
               twiddle_idxs_to_use   : index_2d_array;
               twiddle_vals_to_index : ntt_twiddle_values_to_index;
               invers                : boolean;
               throughput            : integer;
               total_num_stages      : integer; -- for the whole ntt, not just the fully-parallel part
               first_stage_no_mult   : boolean
          );
          port (
               i_clk              : in  std_ulogic;
               i_reset            : in  std_ulogic;
               i_polym            : in  sub_polynom(0 to throughput - 1);
               o_result           : out sub_polynom(0 to throughput - 1);
               o_next_stage_reset : out std_ulogic
          );
     end component;

     component single_stage_base is
          generic (
               prime                 : synthesiseable_uint;
               invers                : boolean;
               twiddle_idxs_to_use   : index_2d_array;
               twiddle_vals_to_index : ntt_twiddle_values_to_index;
               throughput            : integer;
               total_num_stages      : integer;
               no_mult               : boolean
          );
          port (
               i_clk              : in  std_ulogic;
               i_reset            : in  std_ulogic;
               i_polym            : in  sub_polynom(0 to throughput - 1);
               o_result           : out sub_polynom(0 to throughput - 1);
               o_next_stage_reset : out std_ulogic
          );
     end component;

     component ntt_mult_mod_twiddle is
          generic (
               prime : synthesiseable_uint
          );
          port (
               i_clk            : in  std_ulogic;
               i_a_part         : in  synthesiseable_uint;
               i_twiddle_factor : in  synthesiseable_uint;
               o_mod_res        : out synthesiseable_uint
          );
     end component;

     component one_time_counter is
          generic (
               tripping_value     : integer;
               out_negated        : boolean;
               bufferchain_length : integer
          );
          port (
               i_clk     : in  std_ulogic;
               i_reset   : in  std_ulogic;
               o_tripped : out std_ulogic
          );
     end component;

     component ntt_fully_parallel_constant_twiddles is
          generic (
               prime               : synthesiseable_uint;
               num_stages          : integer;
               invers              : boolean;
               first_stage_no_mult : boolean;
               twiddle_values      : ntt_twiddle_values_to_index;
               without_rescaling   : boolean;
               n_invers            : synthesiseable_uint
          );
          port (
               i_clk    : in  std_ulogic;
               i_polym  : in  polynom;
               o_result : out polynom
          );
     end component;

     component stage_overhead_logic_core is
          generic (
               input_size : integer; -- must be a multiple of throughput
               throughput : integer  -- must be a power of 2
          );
          port (
               i_clk                   : in  std_ulogic;
               i_reset                 : in  std_ulogic;
               i_previous_stage_output : in  sub_polynom(0 to throughput - 1);
               o_next_stage_input      : out sub_polynom(0 to throughput - 1);
               o_next_stage_reset      : out std_ulogic
          );
     end component;

     component ntt_format_switcher is
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
     end component;

     constant params             : ntt_params_with_precomputed_values_short := chose_ntt_params(ntt_params, invers);
     constant tw_values_to_index : ntt_twiddle_values_to_index              := get_tw_values_to_index(params);

     constant log2_throughput           : integer := integer(log2(real(throughput)));
     constant num_stages_fully_parallel : integer := log2_throughput;
     constant num_single_stages         : integer := params.total_num_stages - num_stages_fully_parallel;
     constant n                         : integer := 2 ** params.total_num_stages;
     constant total_num_bfs_per_stage   : integer := n / samples_per_butterfly;

     constant twiddles_for_fully_parallel : index_2d_array := get_idx_columns_for_fully_parallel_stages(invers, params.twiddle_indices, num_stages_fully_parallel, params.total_num_stages);

     type sub_polym_size_throughput_array is array (natural range <>) of sub_polynom(0 to throughput - 1);
     signal stages_inputs                   : sub_polym_size_throughput_array(0 to num_single_stages + 1 - 1); -- +1 for the fully parallel input
     signal stages_outputs                  : sub_polym_size_throughput_array(0 to num_single_stages + 1 - 1); -- +1 for the fully parallel output
     signal stage_reset_array               : std_ulogic_vector(0 to num_single_stages + 1 - 1);               -- +1 for fully parallel
     signal next_stage_reset_array          : std_ulogic_vector(0 to num_single_stages + 1 - 1);               -- +1 for fully parallel
     --signal stages_overhead_inputs          : sub_polym_size_throughput_array(0 to num_single_stages + 1 - 1); -- +1 for the fully parallel input
     signal stages_overhead_outputs         : sub_polym_size_throughput_array(0 to num_single_stages + 1 - 1); -- +1 for the fully parallel output
     --signal stage_overhead_reset_array : std_ulogic_vector(0 to num_single_stages + 1 - 1);               -- +1 for fully parallel
     signal next_stage_overhead_reset_array : std_ulogic_vector(0 to num_single_stages + 1 - 1);               -- +1 for fully parallel

     signal result_buffer         : sub_polynom(0 to throughput - 1);
     signal result_buffer_2       : sub_polynom(0 to throughput - 1);
     signal result_reset_buffer_2 : std_ulogic;

     signal next_stage_reset_wait_regs : std_ulogic_vector(0 to (clks_per_ab_mod_p + output_writing_latency) * boolean'pos(invers and not intt_no_final_reduction) + 1 * boolean'pos(not(invers and not intt_no_final_reduction)) + (ntt_twiddle_rams_retiming_latency - 1));

begin

     o_result <= result_buffer;

     sequential_ntt: if num_single_stages > 0 generate

          ntt_flow: if not invers generate
               -- the output is the input of the next stage
               input_cacade: if stages_inputs'length > 1 generate
                    stages_inputs(1 to stages_inputs'length - 1)         <= stages_outputs(0 to stages_outputs'length - 2);
                    stage_reset_array(1 to stage_reset_array'length - 1) <= next_stage_reset_array(0 to next_stage_reset_array'length - 2);
               end generate;

               -- out-stage logic for the input of the fully-parallel stage
               ntt_fully_parallel_stage_logic: stage_overhead_logic_core
                    generic map (
                         input_size => 2 ** num_stages_fully_parallel,
                         throughput => throughput
                    )
                    port map (
                         i_clk                   => i_clk,
                         i_reset                 => stage_reset_array(stage_reset_array'length - 1),
                         i_previous_stage_output => stages_inputs(stages_inputs'length - 1),
                         o_next_stage_input      => stages_overhead_outputs(stages_overhead_outputs'length - 1),
                         o_next_stage_reset      => next_stage_overhead_reset_array(next_stage_overhead_reset_array'length - 1)
                    );

               -- need one more stage logic at the end of the ntt if the output should not be ntt-mixed
               format_switch: if not no_first_last_stage_logic generate
                    in_stage_logic: ntt_format_switcher
                         generic map (
                              input_size => n,
                              invers     => invers,
                              throughput => throughput
                         )
                         port map (
                              i_clk                   => i_clk,
                              i_reset                 => result_reset_buffer_2,
                              i_previous_stage_output => result_buffer_2,
                              o_next_stage_input      => stages_inputs(0),
                              o_next_stage_reset      => stage_reset_array(0)
                         );
               end generate;
               no_format_switch: if no_first_last_stage_logic generate
                    stages_inputs(0)     <= result_buffer_2;
                    stage_reset_array(0) <= result_reset_buffer_2;
               end generate;

               result_buffer_2               <= i_sub_polym;
               result_reset_buffer_2         <= i_reset;
               result_buffer                 <= stages_outputs(stages_outputs'length - 1);
               next_stage_reset_wait_regs(0) <= next_stage_reset_array(next_stage_reset_array'length - 1);
          end generate;

          intt_flow: if invers generate
               -- we reverse the stage order for the intt, so that we can reuse the twiddle-table and other logic from the normal ntt
               -- feed fully-parallel stage, no overhead logic required, just jump over that part
               next_stage_overhead_reset_array(next_stage_overhead_reset_array'length - 1) <= i_reset;
               stages_overhead_outputs(stages_overhead_outputs'length - 1)                 <= i_sub_polym;
               stages_inputs(stages_inputs'length - 1)                                     <= stages_outputs(stages_outputs'length - 1);
               stage_reset_array(stage_reset_array'length - 1)                             <= next_stage_reset_array(next_stage_reset_array'length - 1);

               -- the output is the input of the next stage
               input_cacade: if stages_inputs'length > 1 generate
                    stages_inputs(0 to stages_inputs'length - 2)         <= stages_outputs(1 to stages_outputs'length - 1);
                    stage_reset_array(0 to stage_reset_array'length - 2) <= next_stage_reset_array(1 to next_stage_reset_array'length - 1);
               end generate;

               -- need one more stage logic at the end of the intt if the output should not be ntt-mixed
               format_switch: if not no_first_last_stage_logic generate
                    out_stage_logic: ntt_format_switcher
                         generic map (
                              input_size => n,
                              invers     => invers,
                              throughput => throughput
                         )
                         port map (
                              i_clk                   => i_clk,
                              i_reset                 => next_stage_reset_array(0),
                              i_previous_stage_output => stages_outputs(0),
                              o_next_stage_input      => result_buffer_2,
                              o_next_stage_reset      => result_reset_buffer_2
                         );
               end generate;
               no_format_switch: if no_first_last_stage_logic generate
                    result_buffer_2       <= stages_outputs(0);
                    result_reset_buffer_2 <= next_stage_reset_array(0);
               end generate;

               no_intt_rescaling: if intt_no_final_reduction generate
                    result_buffer <= result_buffer_2;
               end generate;

               intt_rescaling: if not intt_no_final_reduction generate
                    mod_modules: for i in 0 to result_buffer'length - 1 generate
                         ab_mod_p: ntt_mult_mod_twiddle
                              generic map (
                                   prime => params.prime
                              )
                              port map (
                                   i_clk            => i_clk,
                                   i_a_part         => result_buffer_2(i),
                                   i_twiddle_factor => params.n_invers,
                                   o_mod_res        => result_buffer(i)
                              );
                    end generate;
               end generate;
               next_stage_reset_wait_regs(0) <= result_reset_buffer_2;
          end generate;

          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    next_stage_reset_wait_regs(1 to next_stage_reset_wait_regs'length - 1) <= next_stage_reset_wait_regs(0 to next_stage_reset_wait_regs'length - 2);
               end if;
          end process;
          o_next_module_reset <= next_stage_reset_wait_regs(next_stage_reset_wait_regs'length - 1);

          ntt_single_stages: for stage_idx in 0 to num_single_stages - 1 generate
               no_first_buf: if (not invers) and (no_first_last_stage_logic) and (stage_idx = 0) generate
                    next_stage_overhead_reset_array(0) <= stage_reset_array(0);
                    stages_overhead_outputs(0)         <= stages_inputs(0);
               end generate;
               ntt_buf: if not ((not invers) and (no_first_last_stage_logic) and (stage_idx = 0)) generate
                    ntt_stage_logic: stage_overhead_logic_core
                         generic map (
                              input_size => 2 ** (log2_num_coefficients - stage_idx - boolean'pos(invers)),
                              throughput => throughput
                         )
                         port map (
                              i_clk                   => i_clk,
                              i_reset                 => stage_reset_array(stage_idx),
                              i_previous_stage_output => stages_inputs(stage_idx),
                              o_next_stage_input      => stages_overhead_outputs(stage_idx),
                              o_next_stage_reset      => next_stage_overhead_reset_array(stage_idx)
                         );
               end generate;
               ntt_stage: single_stage_base
                    generic map (
                         prime                 => params.prime,
                         invers                => invers,
                         twiddle_idxs_to_use   => params.twiddle_indices(stage_idx * total_num_bfs_per_stage to (stage_idx + 1) * total_num_bfs_per_stage - 1),
                         twiddle_vals_to_index => tw_values_to_index,
                         throughput            => throughput,
                         total_num_stages      => params.total_num_stages,
                         no_mult               => (not params.negacyclic and stage_idx = 0)
                    )
                    port map (
                         i_clk              => i_clk,
                         i_reset            => next_stage_overhead_reset_array(stage_idx),
                         i_polym            => stages_overhead_outputs(stage_idx),
                         o_result           => stages_outputs(stage_idx),
                         o_next_stage_reset => next_stage_reset_array(stage_idx)
                    );
          end generate;

          ntt_fully_parallel_block: ntt_fully_parallel_stage_base
               generic map (
                    prime                 => params.prime,
                    twiddle_idxs_to_use   => twiddles_for_fully_parallel,
                    twiddle_vals_to_index => tw_values_to_index,
                    invers                => invers,
                    throughput            => throughput,
                    total_num_stages      => params.total_num_stages,
                    first_stage_no_mult   => false -- in sequential ntt the fully parallel stage never has only 1's as twiddles
               )
               port map (
                    i_clk              => i_clk,
                    i_reset            => next_stage_overhead_reset_array(next_stage_overhead_reset_array'length - 1),
                    i_polym            => stages_overhead_outputs(stages_overhead_outputs'length - 1),
                    o_result           => stages_outputs(stages_outputs'length - 1),
                    o_next_stage_reset => next_stage_reset_array(next_stage_reset_array'length - 1)
               );
     end generate;

     fully_parallel_ntt: if num_single_stages = 0 generate
          fp_stages: ntt_fully_parallel_constant_twiddles
               generic map (
                    prime               => params.prime,
                    num_stages          => num_stages_fully_parallel,
                    invers              => invers,
                    twiddle_values      => tw_values_to_index,
                    n_invers            => params.n_invers,
                    without_rescaling   => intt_no_final_reduction,
                    first_stage_no_mult => not params.negacyclic
               )
               port map (
                    i_clk    => i_clk,
                    i_polym  => i_sub_polym,
                    o_result => result_buffer
               );

          initial_delay_counter: one_time_counter
               generic map (
                    tripping_value     => get_ntt_latency(params.total_num_stages, log2_throughput, params.negacyclic, invers, not intt_no_final_reduction, false)+ntt_num_clks_reset_early,
                    out_negated        => true,
                    bufferchain_length => trailing_reset_buffer_len
               )
               port map (
                    i_clk     => i_clk,
                    i_reset   => i_reset,
                    o_tripped => o_next_module_reset
               );
     end generate;
end architecture;
