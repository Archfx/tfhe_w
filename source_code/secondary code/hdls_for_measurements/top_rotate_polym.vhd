----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 08:14:04
-- Design Name: 
-- Module Name: top_rotate_polym - Behavioral
-- Project Name: TFHE FPGA Acceleration
-- Target Devices: Virtex Ultrascale+ VCU128
-- Tool Versions: Vivado 2024.1
-- Description: Used to instantiate the rotate_polym module on the FPGA to measure
--             its max operating freqeuncy and resource consumption. This just tests hardware, inputs may not make sense!
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
     use work.math_utils.all;

entity top_rotate_polym is
     port (clk_pin_p : in  STD_LOGIC;
           clk_pin_n : in  STD_LOGIC;
           led_pins  : out STD_LOGIC_VECTOR(7 downto 0) -- v4p ignore w-302
          );
end entity;

architecture Behavioral of top_rotate_polym is
     constant throughput : integer := 2 ** log2_ntt_throughput;

     component rotate_polym_with_buffer is
          generic (
               throughput    : integer;
               rotate_right  : boolean;
               rotate_offset : integer;
               negate_polym  : boolean;
               reverse_polym : boolean
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_sub_polym         : in  sub_polynom(0 to throughput - 1);
               i_rotate_by         : in  rotate_idx;
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     component manual_constant_bram is
          generic (
               ram_content         : sub_polynom;
               addr_length         : integer;
               ram_out_bufs_length : integer;
               ram_type            : string
          );
          port (
               i_clk     : in  std_ulogic;
               i_rd_addr : in  unsigned(0 to addr_length - 1);
               o_data    : out synthesiseable_uint
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

     -- clock and controls
     signal clk_signal : std_logic := 'U';

     signal led_o        : std_ulogic_vector(0 to num_leds - 1);
     signal led_o_buffer : std_ulogic_vector(0 to num_leds - 1);

     signal rotate_reset  : std_ulogic := '1';
     signal rotate_result : sub_polynom(0 to throughput - 1);
     signal rotate_input  : sub_polynom(0 to throughput - 1);

     constant ai_ram_num_coeffs    : integer := 2 ** (log2_coeffs_per_bram - 1);
     constant input_ram_num_coeffs : integer := 2 ** log2_coeffs_per_bram;

     constant cnt_buffer_length    : integer := 2 * log2_ntt_throughput;
     type ai_coeff_cnt_type is array (natural range <>) of unsigned(0 to get_bit_length(ai_ram_num_coeffs - 1) - 1);
     signal ai_coeff_cnt : ai_coeff_cnt_type(0 to cnt_buffer_length - 1);
     
     type in_coeff_cnt_type is array (natural range <>) of unsigned(0 to get_bit_length(input_ram_num_coeffs - 1) - 1);
     signal rotate_in_coeff_cnt : in_coeff_cnt_type(0 to cnt_buffer_length - 1);

     constant num_leds_for_rotate_result : integer := get_min(led_o_buffer'length, rotate_result'length);
     constant num_other_leds             : integer := num_leds - num_leds_for_rotate_result;

     signal led_secondary : std_logic_vector(num_other_leds - 1 downto 0) := (others => 'U');
     signal reset         : std_ulogic_vector(0 to 100 - 1)               := (others => '1');

     signal ai     : rotate_idx;
     signal ai_raw : synthesiseable_uint;

     constant input_ram_content : sub_polynom(0 to throughput * input_ram_num_coeffs - 1) := get_random_test_sub_polym(throughput * input_ram_num_coeffs, 1234);
     constant ai_ram_content    : sub_polynom(0 to ai_ram_num_coeffs - 1)                 := get_random_test_sub_polym(ai_ram_num_coeffs, 12345);

     attribute dont_touch                  : string;
     attribute dont_touch of rotate_input  : signal is "true";
     attribute dont_touch of rotate_result : signal is "true";

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
     rotate_inst: rotate_polym_with_buffer
          generic map (
               throughput    => throughput,
               rotate_right  => true,
               rotate_offset => 1,
               negate_polym  => true,
               reverse_polym => true
          )
          port map (
               i_clk               => clk_signal,
               i_reset             => rotate_reset,
               i_sub_polym         => rotate_input,
               i_rotate_by         => ai,
               o_result            => rotate_result,
               o_next_module_reset => open
          );

     in_coeff_cnt_logic: process (clk_signal) is
     begin
          if rising_edge(clk_signal) then
               if reset(reset'length - 1) = '1' then
                    rotate_in_coeff_cnt(0) <= to_unsigned(0, rotate_in_coeff_cnt(0)'length);
               else
                    rotate_in_coeff_cnt(0) <= rotate_in_coeff_cnt(0) + to_unsigned(1, rotate_in_coeff_cnt(0)'length);
               end if;
               rotate_in_coeff_cnt(1 to rotate_in_coeff_cnt'length - 1) <= rotate_in_coeff_cnt(0 to rotate_in_coeff_cnt'length - 2);
          end if;
     end process;

     ai_coeff_cnt_logic: process (clk_signal) is
     begin
          if rising_edge(clk_signal) then
               if reset(reset'length - 1) = '1' then
                    ai_coeff_cnt(0) <= to_unsigned(0, ai_coeff_cnt(0)'length);
               else
                    ai_coeff_cnt(0) <= ai_coeff_cnt(0) + to_unsigned(1, ai_coeff_cnt(0)'length);
               end if;
               ai_coeff_cnt(1 to ai_coeff_cnt'length - 1) <= ai_coeff_cnt(0 to ai_coeff_cnt'length - 2);
          end if;
     end process;

     process (clk_signal)
     begin
          if rising_edge(clk_signal) then
               reset(0) <= '0';
               reset(1 to reset'length - 1) <= reset(0 to reset'length - 2);

               for i in 0 to num_leds_for_rotate_result - 1 loop
                    led_o(i) <= std_ulogic(rotate_result(i + to_integer(rotate_in_coeff_cnt(rotate_in_coeff_cnt'length-1)))(0));
               end loop;
               led_o_buffer <= led_o;
          end if;
     end process;

     input_ram_blocks: for coeff_idx in 0 to rotate_input'length - 1 generate
          input_ram: manual_constant_bram
               generic map (
                    ram_content         => input_ram_content(coeff_idx * input_ram_num_coeffs to (coeff_idx + 1) * input_ram_num_coeffs - 1),
                    addr_length         => rotate_in_coeff_cnt(0)'length,
                    ram_out_bufs_length => default_ram_retiming_latency,
                    ram_type            => ram_style_auto
               )
               port map (
                    i_clk     => clk_signal,
                    i_rd_addr => rotate_in_coeff_cnt(rotate_in_coeff_cnt'length-1),
                    o_data    => rotate_input(coeff_idx)
               );
     end generate;

     ai_ram: manual_constant_bram
          generic map (
               ram_content         => ai_ram_content,
               addr_length         => ai_coeff_cnt(0)'length,
               ram_out_bufs_length => default_ram_retiming_latency,
               ram_type            => ram_style_auto
          )
          port map (
               i_clk     => clk_signal,
               i_rd_addr => ai_coeff_cnt(ai_coeff_cnt'length-1),
               o_data    => ai_raw
          );
     ai <= ai_raw(ai_raw'length - ai'length to ai_raw'length - 1);

end architecture;
