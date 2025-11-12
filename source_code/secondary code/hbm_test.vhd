----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 08:14:04
-- Design Name: 
-- Module Name: hbm_test - Behavioral
-- Project Name: TFHE FPGA Acceleration
-- Target Devices: Virtex Ultrascale+ VCU128
-- Tool Versions: Vivado 2024.1
-- Description:
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
library work;
     use work.constants_utils.all;
     use work.ip_cores_constants.all;
     use work.datatypes_utils.all;
     -- use work.math_utils.all;
     -- use work.ntt_utils.all;
     use work.processor_utils.all;

entity top is
     -- generic (
     --      CLOCK_RATE : integer := 100_000_000
     -- );
     port (clk_pin_p  : in  STD_LOGIC;
           clk_pin_n  : in  STD_LOGIC;
           clk2_pin_p : in  STD_LOGIC;
           --  clk2_pin_n  : in  STD_LOGIC;
           --  clk3_pin_p  : in  STD_LOGIC;
           --  clk3_pin_n  : in  STD_LOGIC;
           led_pins   : out STD_LOGIC_VECTOR(7 downto 0)
          );
end entity;

architecture Behavioral of top is

     component hbm_wrapper_hbm_0_right is
          port (
               i_clk                : in  std_ulogic;
               i_clk_ref            : in  std_ulogic; -- must be a raw clock pin, hbm-ip-core uses it internally to do the 900MHz clock
               i_clk_apb            : in  std_ulogic;
               i_reset_n            : in  std_ulogic;
               i_reset_n_apb        : in  std_ulogic;
               i_write_pkgs         : in  hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               i_read_pkgs          : in  hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               o_write_pkgs         : out hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               o_read_pkgs          : out hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               o_initial_init_ready : out std_ulogic
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
                clk_out1  : out std_logic;
                clk_out2  : out std_logic
               );
     end component;

     constant num_leds : integer := 8;

     -- clock and controls
     signal clk_signal            : std_logic;
     signal clk_signal_ref        : std_ulogic;
     signal clk_signal_apb_driver : std_ulogic;
     signal clk_signal_apb        : std_ulogic; -- v4p ignore w-302
     signal led_o_buffer          : std_logic_vector(num_leds - 1 downto 0);

     signal reset_n           : std_ulogic := '0';
     signal reset_n_apb       : std_ulogic := '0';
     signal hbm_init_ready    : std_ulogic;

     signal clock_cnt : integer := 0;

     signal read_pkgs_in   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal read_pkgs_out  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal write_pkgs_in  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal write_pkgs_out : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);

begin

     -- define the buffers for the incoming data, clocks, and control
     clk_core_inst: clk_wiz_0
          port map (clk_in1_p => clk_pin_p,
                    clk_in1_n => clk_pin_n,
                    clk_out1  => clk_signal,
                    clk_out2  => clk_signal_apb_driver
          );
     clk_signal_ref <= clk2_pin_p;

     -- define the buffers for the outgoing data
     OBUF_led_ix: for j in 0 to led_o_buffer'length - 1 generate
          -- OBUF = output buffer for signals leaving the chip, amplifies their signal
          OBUF_led_i: OBUF port map (I => led_o_buffer(j), O => LED_pins(j)); -- v4p ignore e-202
     end generate;

     -- BUFG = general high fanout buffer, its input is the output of IBUFG
     BUFG_clk_inst: BUFG -- v4p ignore e-202
          port map (
               O => clk_signal_apb, -- 1-bit output: Clock output.
               I => clk_signal_apb_driver -- 1-bit input: Clock input.
          );
     -- no need for IBUF. Instead tell the clock wizard that its output is going into a BUFG
     -- IBUF_reset_inst: IBUF -- single-ended signal input buffer
     --      port map (
     --           O => reset_n_driver, -- 1-bit output: Buffer output
     --           I => reset_n -- 1-bit input: Buffer input
     --      );

     -- the main code
     my_hbm_inst: hbm_wrapper_hbm_0_right
          port map (
               i_clk                => clk_signal,
               i_clk_ref            => clk_signal_ref,
               i_clk_apb            => clk_signal_apb,
               i_reset_n            => reset_n,
               i_reset_n_apb        => reset_n_apb,
               i_write_pkgs         => write_pkgs_in,
               i_read_pkgs          => read_pkgs_in,
               o_write_pkgs         => write_pkgs_out,
               o_read_pkgs          => read_pkgs_out,
               o_initial_init_ready => hbm_init_ready
          );

     process (clk_signal)
     begin
          if rising_edge(clk_signal) then
               clock_cnt <= clock_cnt + 1;
               -- reset must be asserted for at least one clk_signal_ref clock cycle
               -- reset_n is initialized with 0
               if clock_cnt > 100 then
                    reset_n <= '1';
                    reset_n_apb <= '1';
               end if;

               write_pkgs_in(0).wdata <= std_logic_vector(to_unsigned(1, write_pkgs_in(0).wdata'length));
               write_pkgs_in(0).wdata_parity <= std_logic_vector(to_unsigned(1, write_pkgs_in(0).wdata_parity'length));
               write_pkgs_in(0).awaddr <= to_stack_memory_address(0);
               write_pkgs_in(0).awid <= std_logic_vector(to_unsigned(1, write_pkgs_in(0).awid'length));
               write_pkgs_in(0).awvalid <= '1';
               write_pkgs_in(0).wlast <= '1';
               write_pkgs_in(0).wvalid <= '1';

               read_pkgs_in(0).araddr <= to_stack_memory_address(0);
               read_pkgs_in(0).arid <= std_logic_vector(to_unsigned(1, read_pkgs_in(0).arid'length));
               read_pkgs_in(0).arvalid <= '1';
               read_pkgs_in(0).rready <= '1';

               led_o_buffer(0) <= hbm_init_ready;
               for i in 1 to num_leds - 1 loop
                    led_o_buffer(i) <= std_ulogic(read_pkgs_out(0).rdata(i)); -- LSB out
                    -- led_o_buffer(i) <= std_ulogic(test_hbm_datablock(i)(test_hbm_datablock(0)'length - 1)); -- LSB out
               end loop;

          end if;
     end process;

end architecture;
