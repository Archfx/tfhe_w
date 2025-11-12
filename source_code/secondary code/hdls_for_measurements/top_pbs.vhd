----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 08:14:04
-- Design Name: 
-- Module Name: top_pbs - Behavioral
-- Project Name: TFHE FPGA Acceleration
-- Target Devices: Virtex Ultrascale+ VCU128
-- Tool Versions: Vivado 2024.1
-- Description: Used to instantiate the PBS module on the FPGA to measure
--             its max operating freqeuncy and resource consumption.
--             The outputs are piped to the FPGA's LEDs, such that Vivado does not
--             optimize logic away during implementation.
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.numeric_std.all;

library UNISIM;
     use UNISIM.VComponents.all; -- v4p ignore e-202

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.NUMERIC_STD.all;
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.ntt_utils.all;
     use work.tfhe_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity top is
     port (clk_pin_p  : in  STD_LOGIC;
           clk_pin_n  : in  STD_LOGIC;
           led_pins   : out STD_LOGIC_VECTOR(7 downto 0) -- v4p ignore w-302
          );
end entity;

architecture Behavioral of top is

     component pbs is
          generic (
               throughput                     : integer;
               decomposition_length           : integer; -- for the external product
               num_LSBs_to_round              : integer; -- for the external product
               bits_per_slice                 : integer; -- for the external product
               polyms_per_ciphertext          : integer; -- for the external product
               min_latency_till_monomial_mult : integer; -- for the external product
               num_iterations                 : integer  -- for the blind rotation
          );
          port (
               i_clk                : in  std_ulogic;
               i_reset              : in  std_ulogic;
               i_lookup_table_part  : in  sub_polynom(0 to throughput - 1); -- for the programmable bootstrapping, only a part of an RLWE ciphertext
               i_lwe_b              : in  rotate_idx;
               i_lwe_ai             : in  rotate_idx;
               i_BSK_i_part         : in  sub_polynom(0 to throughput * decomposition_length * polyms_per_ciphertext - 1);
               i_sample_extract_idx : in  idx_int;
               o_sample_extract_idx : out idx_int;
               o_result             : out sub_polynom(0 to throughput - 1);
               o_next_module_reset  : out std_ulogic
          );
     end component;

     -- we keep blink logic, so that we know for certain when the fpga is running
     component blink_logic is
          port (
               clk_rx : in  std_logic;
               led_o  : out std_logic_vector
          );
     end component;

     component clk_wiz_0 is
          port (clk_in1_p : in  std_logic;
                clk_in1_n : in  std_logic;
                clk_out1  : out std_logic
               );
     end component;

     constant num_leds : integer := 8;

     constant throughput : integer := pbs_throughput;

     -- clock and controls
     signal clk_signal   : std_logic                               := 'U';
     signal led_o        : std_logic_vector(num_leds - 1 downto 0) := (others => 'U');
     signal led_o_buffer : std_logic_vector(0 to led_o'length - 1);

     signal pbs_input_choice      : std_ulogic := '0';
     signal pbs_not_ready         : std_ulogic;
     signal pbs_in_coeff_cnt      : idx_int    := to_unsigned(0, log2_num_coefficients);
     signal pbs_lookup_table_part : sub_polynom(0 to throughput - 1);
     signal pbs_result            : sub_polynom(0 to throughput - 1);
     signal pbs_display_coeff_cnt : idx_int    := to_unsigned(0, pbs_result'length);

     signal ai                     : rotate_idx;
     signal b_val                     : rotate_idx;
     signal pbs_sample_extract_idx : idx_int;

     signal bsk_i_part : sub_polynom(0 to throughput * decomp_length * num_polyms_per_rlwe_ciphertext - 1);
     signal input_bsk  : lwe_n_a_dtype(0 to num_polyms_per_rlwe_ciphertext * decomp_length - 1) := get_test_BSKi(1000, 123);

     signal lwe_test_cipher_0   : LWE_memory                               := get_test_lwe_memory(1234 * 2 ** (log2_decomp_base + 1) + 59880, 2 ** (log2_decomp_base + 1), 10 * 2 ** (log2_decomp_base + 1), 2);
     signal lwe_test_cipher_1   : LWE_memory                               := get_test_lwe_memory(5648434, 879533, 7951165, 77777);
     signal lwe_test_cipher     : LWE_memory;
     signal ai_coeff_idx        : unsigned(0 to get_bit_length(k_lwe) - 1) := to_unsigned(0, get_bit_length(k_lwe));
     signal ai_blocks_cnt       : integer                                  := 0;
     signal bsk_polym_coeff_cnt : idx_int                                  := to_unsigned(0, log2_num_coefficients);

     constant num_leds_for_pbs_result : integer := get_min(num_leds, pbs_result'length);
     constant num_other_leds          : integer := num_leds - num_leds_for_pbs_result;

     signal led_secondary : std_logic_vector(num_other_leds - 1 downto 0) := (others => 'U');
     signal reset         : std_ulogic_vector(0 to 4)                     := (others => '1');

     attribute dont_touch               : string;
     attribute dont_touch of pbs_result : signal is "true";
     attribute dont_touch of bsk_i_part : signal is "true";

begin

     -- define the buffers for the incoming data, clocks, and control
     clk_core_inst: clk_wiz_0
          port map (clk_in1_p => clk_pin_p,
                    clk_in1_n => clk_pin_n,
                    clk_out1  => clk_signal
          );

     -- define the buffers for the outgoing data
     OBUF_led_ix: for j in 0 to led_o_buffer'length - 1 generate
          OBUF_led_i: OBUF port map (I => led_o_buffer(j), O => LED_pins(j)); -- v4p ignore e-202
     end generate;

     are_other_leds: if led_secondary'length > 1 generate
          other_leds_control: for i in 0 to led_secondary'length - 1 generate
               led_o(led_o'length - 1 - i) <= led_secondary(i);
          end generate;
          -- instantiate the LED controller
          led_ctl_i0: blink_logic
               port map (
                    clk_rx => clk_signal,
                    led_o  => led_secondary
               );
     end generate;

     -- the main code
     my_pbs: pbs
          generic map (
               throughput                     => throughput,
               decomposition_length           => decomp_length,
               num_LSBs_to_round              => decomp_num_LSBs_to_round,
               bits_per_slice                 => log2_decomp_base,
               polyms_per_ciphertext          => num_polyms_per_rlwe_ciphertext,
               min_latency_till_monomial_mult => blind_rot_iter_min_latency_till_monomial_mult,
               num_iterations                 => k_lwe
          )
          port map (
               i_clk                => clk_signal,
               i_reset              => reset(reset'length - 1),
               i_lookup_table_part  => pbs_lookup_table_part,
               i_lwe_b              => b_val,
               i_lwe_ai             => ai,
               i_BSK_i_part         => bsk_i_part,
               i_sample_extract_idx => sample_extract_default_sample_extract_idx,
               o_sample_extract_idx => pbs_sample_extract_idx,
               o_result             => pbs_result,
               o_next_module_reset  => pbs_not_ready
          );

     process (clk_signal)
     begin
          if rising_edge(clk_signal) then
               b_val <= to_rotate_idx(lwe_test_cipher.lwe.b);
               led_o_buffer <= led_o;
               reset(0) <= '0';
               reset(1 to reset'length - 1) <= reset(0 to reset'length - 2);

               pbs_in_coeff_cnt <= pbs_in_coeff_cnt + to_unsigned(throughput, pbs_in_coeff_cnt'length);
               for i in 0 to pbs_lookup_table_part'length - 1 loop
                    pbs_lookup_table_part(i) <= pbs_default_lookuptable(to_integer(pbs_in_coeff_cnt) + i);
               end loop;

               for i in 0 to num_leds_for_pbs_result - 1 loop
                    led_o(i) <= std_ulogic(pbs_result(i + to_integer(pbs_display_coeff_cnt))(0));
               end loop;

               if pbs_in_coeff_cnt = to_unsigned(0, pbs_in_coeff_cnt'length) then
                    if pbs_input_choice = '0' then
                         lwe_test_cipher <= lwe_test_cipher_0;
                    else
                         lwe_test_cipher <= lwe_test_cipher_1;
                    end if;
                    pbs_input_choice <= not pbs_input_choice;
               end if;

               if pbs_not_ready = '0' then
                    pbs_display_coeff_cnt <= pbs_display_coeff_cnt + to_unsigned(num_leds, pbs_display_coeff_cnt'length);

                    if pbs_input_choice = '1' then
                         for i in 0 to get_min(k_lwe, pbs_result'length) - 1 loop
                              lwe_test_cipher_0.lwe.a(i) <= pbs_result(i);
                         end loop;
                    else
                         for i in 0 to get_min(k_lwe, pbs_result'length) - 1 loop
                              lwe_test_cipher_1.lwe.a(i) <= pbs_result(i);
                         end loop;
                    end if;
               end if;

               ai <= to_rotate_idx(lwe_test_cipher.lwe.a(to_integer(ai_coeff_idx)));
               -- ai is valid for one iteration
               if ai_blocks_cnt < blind_rot_iter_latency - 1 then
                    ai_blocks_cnt <= ai_blocks_cnt + 1;
               else
                    ai_blocks_cnt <= 0;
                    if ai_coeff_idx < to_unsigned(k_lwe - 1, ai_coeff_idx'length) then
                         ai_coeff_idx <= ai_coeff_idx + to_unsigned(1, ai_coeff_idx'length);
                    else
                         ai_coeff_idx <= to_unsigned(0, ai_coeff_idx'length);
                    end if;
               end if;

               for polym_idx in 0 to input_bsk'length - 1 loop
                    for coeff_idx in 0 to throughput - 1 loop
                         bsk_i_part(polym_idx * throughput + coeff_idx) <= input_bsk(polym_idx)(coeff_idx + to_integer(bsk_polym_coeff_cnt));
                    end loop;
               end loop;

          end if;
     end process;

end architecture;
