----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 08:14:04
-- Design Name: 
-- Module Name: top_part_testing_buffer - Behavioral
-- Project Name: TFHE FPGA Acceleration
-- Target Devices: Virtex Ultrascale+ VCU128
-- Tool Versions: Vivado 2024.1
-- Description: Used to instantiate the sub-modules module on the FPGA to measure
--             their max operating freqeuncy and resource consumption.
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
     use work.tfhe_constants.all;
     use work.math_utils.all;

entity top_part_testing_buffer is
     port (clk_pin_p  : in  STD_LOGIC;
           clk_pin_n  : in  STD_LOGIC;
           led_pins   : out STD_LOGIC_VECTOR(7 downto 0) -- v4p ignore w-302
          );
end entity;

architecture Behavioral of top_part_testing_buffer is

     component pbs_lwe_n_storage is
          port (
               i_clk                : in  std_ulogic;
               i_pbs_result         : in  sub_polynom(0 to pbs_throughput - 1); -- only relevant for read_mode='0'
               i_sample_extract_idx : in  idx_int;
               i_reset              : in  std_ulogic;
               o_coeff              : out synthesiseable_uint;
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
     signal clk_signal   : std_logic;
     signal led_o        : std_logic_vector(num_leds - 1 downto 0);
     signal led_o_buffer : std_logic_vector(0 to led_o'length - 1);

     signal input_piece            : sub_polynom(0 to throughput - 1);
     signal throughput_sized_input : sub_polynom(0 to throughput - 1);
     signal lwe_n_buf_result       : sub_polynom(0 to 0);

     constant test_polym : sub_polynom(0 to 2 * throughput - 1) := get_random_test_sub_polym(2 * throughput, 10);
     signal ai_coeff_idx        : idx_int;
     signal rotate_in_coeff_cnt : unsigned(0 to get_bit_length(test_polym'length - 1) - 1) := to_unsigned(0, get_bit_length(test_polym'length - 1));

     -- constant num_leds_for_pbs_result : integer := get_min(num_leds, lwe_n_buf_result'length);
     -- constant num_other_leds          : integer := num_leds - num_leds_for_pbs_result;

     -- signal led_secondary : std_logic_vector(num_other_leds - 1 downto 0) := (others => 'U');
     signal reset : std_ulogic_vector(0 to 2 * throughput) := (others => '1');

     attribute dont_touch                           : string;
     attribute dont_touch of lwe_n_buf_result       : signal is "true";
     attribute dont_touch of ai_coeff_idx           : signal is "true";
     attribute dont_touch of throughput_sized_input : signal is "true";

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

     -- -- instantiate the LED controller
     -- led_ctl_i0: blink_logic
     --      port map (
     --           clk_rx => clk_signal,
     --           led_o  => led_secondary
     --      );

     -- are_other_leds: if led_secondary'length > 1 generate
     --      other_leds_control: for i in 0 to led_secondary'length - 1 generate
     --           led_o(led_o'length - 1 - i) <= led_secondary(i);
     --      end generate;
     -- end generate;
     ai_coeff_cnt_logic: process (clk_signal) is
     begin
          if rising_edge(clk_signal) then
               if reset(reset'length - 1) = '1' then
                    ai_coeff_idx <= to_unsigned(0, ai_coeff_idx'length);
               else
                    ai_coeff_idx <= ai_coeff_idx + to_unsigned(1, ai_coeff_idx'length);                    
               end if;
          end if;
     end process;

     in_coeff_cnt_logic: process (clk_signal) is
     begin
          if rising_edge(clk_signal) then
               if reset(reset'length - 1) = '1' then
                    rotate_in_coeff_cnt <= to_unsigned(0, rotate_in_coeff_cnt'length);
               else
                    rotate_in_coeff_cnt <= rotate_in_coeff_cnt + to_unsigned(throughput, rotate_in_coeff_cnt'length);                    
               end if;
          end if;
     end process;

     dut: pbs_lwe_n_storage
          port map (
               i_clk                => clk_signal,
               i_pbs_result         => throughput_sized_input,
               i_sample_extract_idx => ai_coeff_idx,
               i_reset              => reset(reset'length - 1),
               o_coeff              => lwe_n_buf_result(0),
               o_next_module_reset  => open
          );

     process (clk_signal)
     begin
          if rising_edge(clk_signal) then
               if reset(0) = '1' then
                    -- init
               end if;
               led_o_buffer <= led_o;
               reset(0) <= '0';
               reset(1 to reset'length - 1) <= reset(0 to reset'length - 2);

               for i in 0 to num_leds - 1 loop
                    led_o(i) <= std_ulogic(lwe_n_buf_result(0)(i));
               end loop;

               for i in 0 to input_piece'length - 1 loop
                    input_piece(i) <= test_polym(to_integer(rotate_in_coeff_cnt) + i);
               end loop;

               throughput_sized_input <= input_piece;

          end if;
     end process;

end architecture;
