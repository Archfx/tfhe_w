----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.09.2024 08:38:39
-- Design Name: 
-- Module Name: hbm_tb - Behavioral
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
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.tfhe_constants.all;
     use work.tb_utils.all;
     use work.processor_utils.all;
     use work.ip_cores_constants.all;

entity hbm_tb is
     --  Port ( );
end entity;

architecture Behavioral of hbm_tb is

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

     signal clk         : std_logic := '0';
     signal clk_ref     : std_logic := '0';
     signal reset_n     : std_logic;
     signal reset_n_apb : std_logic;
     signal finished    : std_logic := '0';

     signal clk_cnt     : integer := 0;
     signal clk_cnt_ref : integer := 0;

     constant clk_period       : time := 2.5 ns; -- 400 MHz, clk_ref=100MHz
     constant TIME_DELTA       : time := clk_period / 2;
     constant next_sample_time : time := clk_period;

     signal hbm_init_ready : std_ulogic;

     signal read_pkgs_in   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal read_pkgs_out  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1); -- v4p ignore w-303
     signal write_pkgs_in  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal write_pkgs_out : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);

begin
     clk <= not clk after TIME_DELTA when finished /= '1' else '0';

     dut: hbm_wrapper_hbm_0_right
          port map (
               i_clk                => clk,
               i_clk_ref            => clk,--clk_ref,
               i_clk_apb            => clk,--clk_ref,
               i_reset_n            => reset_n,
               i_reset_n_apb        => reset_n_apb,
               i_write_pkgs         => write_pkgs_in,
               i_read_pkgs          => read_pkgs_in,
               o_write_pkgs         => write_pkgs_out,
               o_read_pkgs          => read_pkgs_out,
               o_initial_init_ready => hbm_init_ready
          );

     process (clk)
     begin
          if clk_cnt_ref < 4 - 1 then -- 4 = 10ns (for 100MHz) /2.5ns (for 400MHz)
               clk_cnt_ref <= clk_cnt_ref + 1;
          else
               clk_cnt_ref <= 0;
               clk_ref <= not clk_ref;
          end if;

          if rising_edge(clk) then
               if reset_n = '0' then
                    clk_cnt <= 0;
               else
                    clk_cnt <= clk_cnt + 1;
               end if;
          end if;
     end process;

     simulation: process
     begin
          reset_n <= '0';
          reset_n_apb <= '0';

          write_pkgs_in(0).bready <= '0';
          write_pkgs_in(0).awvalid <= '0';
          write_pkgs_in(0).wlast <= '0';
          write_pkgs_in(0).wvalid <= '0';
          read_pkgs_in(0).arvalid <= '0';
          read_pkgs_in(0).rready <= '0';
          read_pkgs_in(0).arvalid <= '0';

          wait for 4700 ns; -- like in the example. Expect apb_complete at around 50µs
          -- arready, awready, wready get high even before that at around 48µs
          reset_n_apb <= '1';

          wait until hbm_init_ready = '1';

          -- write data
          reset_n <= '1';
          write_pkgs_in(0).wdata <= std_logic_vector(to_unsigned(1, write_pkgs_in(0).wdata'length));
          write_pkgs_in(0).wdata_parity <= std_logic_vector(to_unsigned(1, write_pkgs_in(0).wdata_parity'length));
          write_pkgs_in(0).awaddr <= to_stack_memory_address(0);
          write_pkgs_in(0).awid <= std_logic_vector(to_unsigned(1, write_pkgs_in(0).awid'length));
          write_pkgs_in(0).awvalid <= '1';
          write_pkgs_in(0).wlast <= '1';
          write_pkgs_in(0).wvalid <= '1';

          wait until write_pkgs_out(0).wready = '1';
          write_pkgs_in(0).bready <= '1';
          -- read data
          read_pkgs_in(0).araddr <= to_stack_memory_address(0);
          read_pkgs_in(0).arid <= std_logic_vector(to_unsigned(1, read_pkgs_in(0).arid'length));
          read_pkgs_in(0).arvalid <= '1';
          read_pkgs_in(0).rready <= '1';
          read_pkgs_in(0).arvalid <= '1';

          wait for TIME_DELTA; -- so that there can be no confusion when reading the output signal
          wait for next_sample_time;
          wait for next_sample_time;

          report "Check correctness manually!" severity warning;
          finished <= '1';
          wait;
     end process;

end architecture;
