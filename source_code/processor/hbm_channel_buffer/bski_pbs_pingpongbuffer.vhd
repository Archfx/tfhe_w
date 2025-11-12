----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: bski_pbs_pingpongbuffer.vhd
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: takes bski for the pbs and buffers it in a way that it provides the signals at the correct time for the pbs.
--             bsk_hbm_coeffs_per_clk must be a power of 2 that is smaller than o_bski_part'length.
--             A ping-pong buffer is used. The module requests data from hbm and uses that to fill the buffers.
--             The ping buffer is written to in the beginning. After that it is ready for the pbs. While one buffer provides
--             bsk_i for the pbs the other buffer is filled by bsk_(i+1).
--             Every blind rotation iteration the buffers switch function. This is called batched bootstrapping and
--             amortized the bski loading time.
--             Bsk_i is required for every ciphertext of the batch. So we read bsk_i batchsize-many times before
--             we need bsk_(i+1).
--             When using burst only every burstlen-address that this module outputs is actually read by hbm.
--             We still update the read address every clock tic in case burstlength changes.
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
     use work.ip_cores_constants.all;
     use work.datatypes_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity bski_pbs_pingpongbuffer is
     port (
          i_clk                    : in  std_ulogic;
          i_pbs_reset              : in  std_ulogic;
          i_reset_n                : in  std_ulogic;
          i_hbm_ps_in_read_out_pkg : in  hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
          o_hbm_ps_in_read_in_pkg  : out hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
          o_bski_part              : out sub_polynom(0 to pbs_bsk_coeffs_needed_per_clk - 1);
          o_ready_to_output        : out std_ulogic
     );
end entity;

architecture Behavioral of bski_pbs_pingpongbuffer is

     -- memory pattern: receive input-blocks, store and assemble them till size of output-block
     -- return sequentially all out-blocks pbs_batchsize-times
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

     component manual_bram is
          generic (
               addr_length         : integer;
               ram_length          : integer;
               ram_out_bufs_length : integer;
               ram_type            : string;
               coeff_bit_width     : integer
          );
          port (
               i_clk     : in  std_ulogic;
               i_wr_en   : in  std_ulogic;
               i_wr_data : in  unsigned(0 to coeff_bit_width - 1);
               i_wr_addr : in  unsigned(0 to addr_length - 1);
               i_rd_addr : in  unsigned(0 to addr_length - 1);
               o_data    : out unsigned(0 to coeff_bit_width - 1)
          );
     end component;

     constant num_blocks_per_rlwe_ciphertext    : integer := num_polyms_per_rlwe_ciphertext * ntt_num_blocks_per_polym;
     constant clks_till_next_bski_must_be_ready : integer := num_blocks_per_rlwe_ciphertext * pbs_batchsize;
     constant clks_per_bski_part_load           : integer := integer(ceil(real(num_polyms_per_rlwe_ciphertext * bsk_hbm_coeffs_per_clk) / real(bsk_hbm_coeffs_per_clk)));
     constant clks_per_bski_load                : integer := ntt_num_blocks_per_polym * clks_per_bski_part_load;
     constant worst_case_clks_per_bski_load     : integer := clks_per_bski_load + hbm_worst_case_delay_in_clks;

     signal bski_buf_input  : sub_polynom(0 to o_bski_part'length - 1);
     signal hbm_part_buffer : sub_polynom(0 to bsk_hbm_coeffs_per_clk - 1);
     constant ping_buf_length : integer := num_blocks_per_rlwe_ciphertext;
     constant bski_buf_length : integer := 2 * ping_buf_length;

     signal bski_buf_input_buf : sub_polynom(0 to bski_buf_input'length - 1);

     signal enough_rqs_to_fill_buf : std_ulogic;
     signal init_done              : std_ulogic;
     signal receive_block_cnt      : unsigned(0 to get_bit_length(bski_buf_length - 1) - 1); -- is a power of 2 --> modulos itself
     signal rq_block_cnt           : unsigned(0 to get_bit_length(ping_buf_length - 1) - 1);
     constant num_sub_blocks        : integer := o_bski_part'length / bsk_hbm_coeffs_per_clk;              -- is a power of 2
     constant num_sub_blocks_coeffs : integer := get_max(1,(num_sub_blocks - 1) * bsk_hbm_coeffs_per_clk); -- is a power of 2
     signal receive_sub_block_coeff_cnt         : unsigned(0 to get_bit_length(num_sub_blocks_coeffs) - 1);
     signal receive_sub_block_coeff_cnt_delayed : unsigned(0 to receive_sub_block_coeff_cnt'length - 1);
     signal rq_sub_block_cnt                    : unsigned(0 to receive_sub_block_coeff_cnt'length - 1);

     signal out_part_cnt : unsigned(0 to receive_block_cnt'length - 1); -- modulos itself

     signal receive_block_cnt_offset : unsigned(0 to receive_block_cnt'length - 1);
     signal receive_block_cnt_full   : unsigned(0 to receive_block_cnt'length - 1);
     signal out_part_cnt_offset      : unsigned(0 to out_part_cnt'length - 1);
     signal out_part_cnt_full        : unsigned(0 to out_part_cnt'length - 1);

     signal out_batchsize_cnt : unsigned(0 to get_bit_length(pbs_batchsize - 1) - 1);

     signal start_outputting : std_ulogic;

     signal bski_rq_addr : hbm_ps_port_memory_address;
     signal hbm_part     : sub_polynom(0 to bsk_hbm_coeffs_per_clk - 1);
     signal read_pkg     : hbm_ps_in_read_pkg;

     signal write_en_vec     : std_ulogic_vector(0 to o_bski_part'length - 1);
     signal write_en_vec_buf : std_ulogic_vector(0 to write_en_vec'length - 1);

begin

     -- we assume that the HBM is more than fast enough to write to the buffer, so it will never be late but can be too early
     speed_requirement_check: if clks_till_next_bski_must_be_ready < worst_case_clks_per_bski_load generate
          assert false report "Sorry - HBM not fast enough for this configuration" severity error;
     end generate;

     crtl_logic: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_reset_n = '0' then
                    enough_rqs_to_fill_buf <= '0';

                    out_part_cnt_offset <= to_unsigned(0, out_part_cnt_offset'length);
                    rq_sub_block_cnt <= to_unsigned(0, rq_sub_block_cnt'length);
                    rq_block_cnt <= to_unsigned(0, rq_block_cnt'length);
                    init_done <= '0';
                    read_pkg.arvalid <= '0';

                    bski_rq_addr <= bsk_base_addr;
               else
                    if i_hbm_ps_in_read_out_pkg(0).arready = '1' and enough_rqs_to_fill_buf = '0' then
                         -- increment request address
                         if bski_rq_addr < bsk_end_addr - to_unsigned(1, bski_rq_addr'length) then
                              bski_rq_addr <= bski_rq_addr + to_unsigned(hbm_bytes_per_ps_port, bski_rq_addr'length);
                         else
                              bski_rq_addr <= bsk_base_addr;
                         end if;
                         read_pkg.arvalid <= '1';

                         if rq_sub_block_cnt < to_unsigned(num_sub_blocks_coeffs - 1, rq_sub_block_cnt'length) then
                              rq_sub_block_cnt <= rq_sub_block_cnt + to_unsigned(bsk_hbm_coeffs_per_clk, rq_sub_block_cnt'length);
                         else
                              rq_sub_block_cnt <= to_unsigned(0, rq_sub_block_cnt'length);
                              if rq_block_cnt < to_unsigned(ping_buf_length - 1, rq_block_cnt'length) then
                                   rq_block_cnt <= rq_block_cnt + to_unsigned(1, rq_block_cnt'length);
                              else
                                   rq_block_cnt <= to_unsigned(0, rq_block_cnt'length);
                              end if;
                         end if;
                    else
                         read_pkg.arvalid <= '0';
                    end if;

                    if out_batchsize_cnt = to_unsigned(pbs_batchsize - 1, out_batchsize_cnt'length) then
                         enough_rqs_to_fill_buf <= '0';
                    else
                         if rq_block_cnt = to_unsigned(ping_buf_length - 1, rq_block_cnt'length) then
                              if init_done = '0' then
                                   init_done <= '1';
                              else
                                   enough_rqs_to_fill_buf <= '1';
                              end if;
                         end if;
                    end if;

               end if;

               if start_outputting = '1' then
                    if out_part_cnt < to_unsigned(ping_buf_length - 1, out_part_cnt'length) then
                         out_part_cnt <= out_part_cnt + to_unsigned(1, out_part_cnt'length);
                    else
                         out_part_cnt <= to_unsigned(0, out_part_cnt'length);
                         out_part_cnt_offset <= out_part_cnt_offset + to_unsigned(ping_buf_length, out_part_cnt_offset'length);
                         if out_batchsize_cnt < to_unsigned(pbs_batchsize - 1, out_batchsize_cnt'length) then
                              out_batchsize_cnt <= out_batchsize_cnt + to_unsigned(1, out_batchsize_cnt'length);
                         else
                              out_batchsize_cnt <= to_unsigned(0, out_batchsize_cnt'length);
                         end if;
                    end if;
               else
                    out_part_cnt <= to_unsigned(0, out_part_cnt'length);
                    out_batchsize_cnt <= to_unsigned(0, out_batchsize_cnt'length);
               end if;

          end if;
     end process;

     -- we expect that the requests are handled in the same order as we send them. We dont check the ids.
     read_pkg.rready <= '1';
     read_pkg.arid   <= std_logic_vector(to_unsigned(0, read_pkg.arid'length)); -- should not be important for this module
     read_pkg.arlen  <= std_logic_vector(to_unsigned(bsk_burstlen, read_pkg.arlen'length));
     read_pkg.araddr <= bski_rq_addr;

     rq_and_receive_cnts: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_reset_n = '0' then
                    o_ready_to_output <= '0';
                    receive_block_cnt <= to_unsigned(0, receive_block_cnt'length);
                    receive_block_cnt_offset <= to_unsigned(0, receive_block_cnt_offset'length);
                    receive_sub_block_coeff_cnt <= to_unsigned(0, receive_sub_block_coeff_cnt'length);
               else
                    -- receive logic
                    if i_hbm_ps_in_read_out_pkg(0).rvalid = '1' then
                         if receive_sub_block_coeff_cnt < to_unsigned(num_sub_blocks_coeffs - 1, receive_sub_block_coeff_cnt'length) then
                              receive_sub_block_coeff_cnt <= receive_sub_block_coeff_cnt + to_unsigned(bsk_hbm_coeffs_per_clk, receive_sub_block_coeff_cnt'length);
                         else
                              receive_sub_block_coeff_cnt <= to_unsigned(0, receive_sub_block_coeff_cnt'length);
                              if receive_block_cnt < to_unsigned(ping_buf_length - 1, receive_block_cnt'length) then
                                   receive_block_cnt <= receive_block_cnt + to_unsigned(1, receive_block_cnt'length);
                              else
                                   receive_block_cnt <= to_unsigned(0, receive_block_cnt'length);
                                   o_ready_to_output <= '1';
                                   receive_block_cnt_offset <= receive_block_cnt_offset + to_unsigned(ping_buf_length, receive_block_cnt_offset'length);
                              end if;
                         end if;
                    end if;
               end if;
               bski_buf_input_buf <= bski_buf_input;
               receive_block_cnt_full <= receive_block_cnt + receive_block_cnt_offset;
               out_part_cnt_full <= out_part_cnt + out_part_cnt_offset;
          end if;
     end process;

     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => blind_rot_iter_latency_till_elem_wise_mult - default_ram_retiming_latency - 1,
               out_negated        => false,
               bufferchain_length => log2_pbs_throughput
          )
          port map (
               i_clk     => i_clk,
               i_reset   => i_pbs_reset,
               o_tripped => start_outputting
          );

     bski_brams: for coeff_idx in 0 to o_bski_part'length - 1 generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    if receive_sub_block_coeff_cnt = to_unsigned(coeff_idx - coeff_idx mod bsk_hbm_coeffs_per_clk, receive_sub_block_coeff_cnt'length) then
                         write_en_vec(coeff_idx) <= '1';
                    else
                         write_en_vec(coeff_idx) <= '0';
                    end if;
                    write_en_vec_buf(coeff_idx) <= write_en_vec(coeff_idx);
               end if;
          end process;
          ram_elem: manual_bram
               generic map (
                    addr_length         => receive_block_cnt_full'length,
                    ram_length          => bski_buf_length,
                    ram_out_bufs_length => default_ram_retiming_latency,
                    ram_type            => ram_style_bram,
                    coeff_bit_width     => bski_buf_input(0)'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => write_en_vec_buf(coeff_idx),
                    i_wr_data => bski_buf_input_buf(coeff_idx),
                    i_wr_addr => receive_block_cnt_full,
                    i_rd_addr => out_part_cnt_full,
                    o_data    => o_bski_part(coeff_idx)
               );
     end generate;

     bits2coeffs: for coeff_idx in 0 to hbm_part'length - 1 generate
          bits2bits: for bit_idx in 0 to hbm_part(0)'length - 1 generate
               hbm_part(coeff_idx)(bit_idx) <= i_hbm_ps_in_read_out_pkg(coeff_idx / hbm_coeffs_per_clock_per_ps_port).rdata((coeff_idx mod hbm_coeffs_per_clock_per_ps_port) * hbm_part(0)'length + bit_idx);
          end generate;
     end generate;

     input_buffer: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               hbm_part_buffer <= hbm_part;
               receive_sub_block_coeff_cnt_delayed <= receive_sub_block_coeff_cnt;
               if i_hbm_ps_in_read_out_pkg(0).rvalid = '1' then
                    for i in 0 to bsk_hbm_coeffs_per_clk - 1 loop
                         bski_buf_input(i + to_integer(receive_sub_block_coeff_cnt_delayed)) <= hbm_part_buffer(i);
                    end loop;
               end if;
          end if;
     end process;

     -- bsk buffer treats its hbm channels as one. Need to replicate the signal correctly with the addresses
     one_port_to_many: for port_idx in 0 to o_hbm_ps_in_read_in_pkg'length - 1 generate
          o_hbm_ps_in_read_in_pkg(port_idx).arid    <= read_pkg.arid;
          o_hbm_ps_in_read_in_pkg(port_idx).arlen   <= read_pkg.arlen;
          o_hbm_ps_in_read_in_pkg(port_idx).arvalid <= read_pkg.arvalid;
          o_hbm_ps_in_read_in_pkg(port_idx).rready  <= read_pkg.rready;
          -- set the addr-bits that lead to the channel, keep the channel addr-bits
          o_hbm_ps_in_read_in_pkg(port_idx).araddr(hbm_port_and_stack_addr_width - 1 downto 0)                                        <= bsk_base_addr(hbm_port_and_stack_addr_width - 1 downto 0) + to_unsigned(port_idx, hbm_port_and_stack_addr_width);
          o_hbm_ps_in_read_in_pkg(port_idx).araddr(o_hbm_ps_in_read_in_pkg(0).araddr'length - 1 downto hbm_port_and_stack_addr_width) <= read_pkg.araddr(o_hbm_ps_in_read_in_pkg(0).araddr'length - 1 downto hbm_port_and_stack_addr_width);
     end generate;

end architecture;
