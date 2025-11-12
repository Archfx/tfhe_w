----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: axi_crossbar_0_wrapper
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description:
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
library work;
     use work.ip_cores_constants.all;
     use work.processor_utils.all;

entity axi_crossbar_0_wrapper is
     generic (
          num_axi_slaves : integer
     );
     port (
          i_clk           : in  std_ulogic;
          i_reset_n       : in  std_ulogic;
          i_write_pkgs    : in  axi_in_write_pkg;                                  -- small pkg from master
          i_read_pkgs     : in  axi_in_read_pkg;                                   -- small pkg from master

          i_hbm_read_out  : in  hbm_ps_out_read_pkg_arr(0 to num_axi_slaves - 1);  -- big pkg for master from slaves
          i_hbm_write_out : in  hbm_ps_out_write_pkg_arr(0 to num_axi_slaves - 1); -- big pkg for master from slaves
          o_hbm_read_in   : out hbm_ps_in_read_pkg_arr(0 to num_axi_slaves - 1);   -- big pkg for slaves from master
          o_hbm_write_in  : out hbm_ps_in_write_pkg_arr(0 to num_axi_slaves - 1);  -- big pkg for slaves from master

          o_write_pkgs    : out axi_out_write_pkg;                                 -- small pkg from one slave for the master
          o_read_pkgs     : out axi_out_read_pkg                                   -- small pkg from one slave for the master
     );
end entity;

architecture Behavioral of axi_crossbar_0_wrapper is

     component axi_crossbar_0 is
          port (
               aclk           : in  std_logic;
               aresetn        : in  std_logic;

               s_axi_awid     : in  std_logic_vector(num_axi_slave_interfaces * axi_id_bit_width - 1 downto 0);
               s_axi_awaddr   : in  std_logic_vector(num_axi_slave_interfaces * axi_addr_bits - 1 downto 0);
               s_axi_awlen    : in  std_logic_vector(num_axi_slave_interfaces * axi_len_bits - 1 downto 0);
               s_axi_awsize   : in  std_logic_vector(num_axi_slave_interfaces * axi_burstsize_bits - 1 downto 0);
               s_axi_awburst  : in  std_logic_vector(num_axi_slave_interfaces * axi_burstmode_bits - 1 downto 0);
               s_axi_awlock   : in  std_logic_vector(num_axi_slave_interfaces - 1 downto 0); -- locks the channel until unlocked. AXI4 supports values 0=normal, 1=exclusive
               s_axi_awcache  : in  std_logic_vector(num_axi_slave_interfaces * axi_cache_bits - 1 downto 0);
               s_axi_awprot   : in  std_logic_vector(num_axi_slave_interfaces * axi_prot_bits - 1 downto 0);
               s_axi_awqos    : in  std_logic_vector(num_axi_slave_interfaces * axi_qos_bits - 1 downto 0);
               s_axi_awvalid  : in  std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_wdata    : in  std_logic_vector(num_axi_slave_interfaces * axi_pkg_bit_size - 1 downto 0);
               s_axi_wstrb    : in  std_logic_vector(num_axi_slave_interfaces * axi_strobe_bits - 1 downto 0);
               s_axi_wlast    : in  std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_wvalid   : in  std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_bready   : in  std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_arid     : in  std_logic_vector(num_axi_slave_interfaces * axi_id_bit_width - 1 downto 0);
               s_axi_araddr   : in  std_logic_vector(num_axi_slave_interfaces * axi_addr_bits - 1 downto 0);
               s_axi_arlen    : in  std_logic_vector(num_axi_slave_interfaces * axi_len_bits - 1 downto 0);
               s_axi_arsize   : in  std_logic_vector(num_axi_slave_interfaces * axi_burstsize_bits - 1 downto 0);
               s_axi_arburst  : in  std_logic_vector(num_axi_slave_interfaces * axi_burstmode_bits - 1 downto 0);
               s_axi_arlock   : in  std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_arcache  : in  std_logic_vector(num_axi_slave_interfaces * axi_cache_bits - 1 downto 0);
               s_axi_arprot   : in  std_logic_vector(num_axi_slave_interfaces * axi_prot_bits - 1 downto 0);
               s_axi_arqos    : in  std_logic_vector(num_axi_slave_interfaces * axi_qos_bits - 1 downto 0);
               s_axi_arvalid  : in  std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_rready   : in  std_logic_vector(num_axi_slave_interfaces - 1 downto 0);

               s_axi_awready  : out std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_wready   : out std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_bid      : out std_logic_vector(num_axi_slave_interfaces * axi_id_bit_width - 1 downto 0);
               s_axi_bresp    : out std_logic_vector(num_axi_slave_interfaces * axi_resp_bits - 1 downto 0);
               s_axi_bvalid   : out std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_arready  : out std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_rid      : out std_logic_vector(num_axi_slave_interfaces * axi_id_bit_width - 1 downto 0);
               s_axi_rdata    : out std_logic_vector(num_axi_slave_interfaces * axi_pkg_bit_size - 1 downto 0);
               s_axi_rresp    : out std_logic_vector(num_axi_slave_interfaces * axi_resp_bits - 1 downto 0);
               s_axi_rlast    : out std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
               s_axi_rvalid   : out std_logic_vector(num_axi_slave_interfaces - 1 downto 0);

               m_axi_awready  : in  std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_wready   : in  std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_bid      : in  std_logic_vector(num_axi_slaves * axi_id_bit_width - 1 downto 0);
               m_axi_bresp    : in  std_logic_vector(num_axi_slaves * axi_resp_bits - 1 downto 0);
               m_axi_bvalid   : in  std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_arready  : in  std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_rid      : in  std_logic_vector(num_axi_slaves * axi_id_bit_width - 1 downto 0);
               m_axi_rdata    : in  std_logic_vector(num_axi_slaves * axi_pkg_bit_size - 1 downto 0);
               m_axi_rresp    : in  std_logic_vector(num_axi_slaves * axi_resp_bits - 1 downto 0);
               m_axi_rlast    : in  std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_rvalid   : in  std_logic_vector(num_axi_slaves - 1 downto 0);

               m_axi_awid     : out std_logic_vector(num_axi_slaves * axi_id_bit_width - 1 downto 0);
               m_axi_awaddr   : out std_logic_vector(num_axi_slaves * axi_addr_bits - 1 downto 0);
               m_axi_awlen    : out std_logic_vector(num_axi_slaves * axi_len_bits - 1 downto 0);
               m_axi_awsize   : out std_logic_vector(num_axi_slaves * axi_burstsize_bits - 1 downto 0);
               m_axi_awburst  : out std_logic_vector(num_axi_slaves * axi_burstmode_bits - 1 downto 0);
               m_axi_awlock   : out std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_awcache  : out std_logic_vector(num_axi_slaves * axi_cache_bits - 1 downto 0);
               m_axi_awprot   : out std_logic_vector(num_axi_slaves * axi_prot_bits - 1 downto 0);
               m_axi_awqos    : out std_logic_vector(num_axi_slaves * axi_qos_bits - 1 downto 0);
               m_axi_awvalid  : out std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_wdata    : out std_logic_vector(num_axi_slaves * axi_pkg_bit_size - 1 downto 0);
               m_axi_wstrb    : out std_logic_vector(num_axi_slaves * axi_strobe_bits - 1 downto 0);
               m_axi_wlast    : out std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_wvalid   : out std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_bready   : out std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_arid     : out std_logic_vector(num_axi_slaves * axi_id_bit_width - 1 downto 0);
               m_axi_araddr   : out std_logic_vector(num_axi_slaves * axi_addr_bits - 1 downto 0);
               m_axi_arlen    : out std_logic_vector(num_axi_slaves * axi_len_bits - 1 downto 0);
               m_axi_arsize   : out std_logic_vector(num_axi_slaves * axi_burstsize_bits - 1 downto 0);
               m_axi_arburst  : out std_logic_vector(num_axi_slaves * axi_burstmode_bits - 1 downto 0);
               m_axi_arlock   : out std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_arcache  : out std_logic_vector(num_axi_slaves * axi_cache_bits - 1 downto 0);
               m_axi_arprot   : out std_logic_vector(num_axi_slaves * axi_prot_bits - 1 downto 0);
               m_axi_arqos    : out std_logic_vector(num_axi_slaves * axi_qos_bits - 1 downto 0);
               m_axi_arvalid  : out std_logic_vector(num_axi_slaves - 1 downto 0);
               m_axi_rready   : out std_logic_vector(num_axi_slaves - 1 downto 0);

               m_axi_awregion : out std_logic_vector(num_axi_slaves * axi_region_bits - 1 downto 0);
               m_axi_arregion : out std_logic_vector(num_axi_slaves * axi_region_bits - 1 downto 0)
          );
     end component;

     signal m_awready : std_logic_vector(num_axi_slaves - 1 downto 0);
     signal m_wready  : std_logic_vector(num_axi_slaves - 1 downto 0);
     signal m_bid     : std_logic_vector(num_axi_slaves * axi_id_bit_width - 1 downto 0);
     signal m_bresp   : std_logic_vector(num_axi_slaves * axi_resp_bits - 1 downto 0);
     signal m_bvalid  : std_logic_vector(num_axi_slaves - 1 downto 0);
     signal m_arready : std_logic_vector(num_axi_slaves - 1 downto 0);
     signal m_rid     : std_logic_vector(num_axi_slaves * axi_id_bit_width - 1 downto 0);
     signal m_rdata   : std_logic_vector(num_axi_slaves * axi_pkg_bit_size - 1 downto 0);
     signal m_rresp   : std_logic_vector(num_axi_slaves * axi_resp_bits - 1 downto 0);
     signal m_rlast   : std_logic_vector(num_axi_slaves - 1 downto 0);
     signal m_rvalid  : std_logic_vector(num_axi_slaves - 1 downto 0);

     signal m_awid   : std_logic_vector(num_axi_slaves * axi_id_bit_width - 1 downto 0);
     signal m_awaddr : std_logic_vector(num_axi_slaves * axi_addr_bits - 1 downto 0);
     signal m_awlen  : std_logic_vector(num_axi_slaves * axi_len_bits - 1 downto 0);
     -- signal m_awsize   : std_logic_vector(num_axi_slaves * axi_burstsize_bits - 1 downto 0);
     -- signal m_awburst  : std_logic_vector(num_axi_slaves * axi_burstmode_bits - 1 downto 0);
     -- signal m_awlock   : std_logic_vector(num_axi_slaves - 1 downto 0);
     -- signal m_awcache  : std_logic_vector(num_axi_slaves * axi_cache_bits - 1 downto 0);
     -- signal m_awprot   : std_logic_vector(num_axi_slaves * axi_prot_bits - 1 downto 0);
     -- signal m_awqos    : std_logic_vector(num_axi_slaves * axi_qos_bits - 1 downto 0);
     -- signal m_wstrb    : std_logic_vector(num_axi_slaves * axi_strobe_bits - 1 downto 0);
     signal m_awvalid : std_logic_vector(num_axi_slaves - 1 downto 0);
     signal m_wdata   : std_logic_vector(num_axi_slaves * axi_pkg_bit_size - 1 downto 0);
     signal m_wlast   : std_logic_vector(num_axi_slaves - 1 downto 0);
     signal m_wvalid  : std_logic_vector(num_axi_slaves - 1 downto 0);
     signal m_bready  : std_logic_vector(num_axi_slaves - 1 downto 0);

     signal m_arid    : std_logic_vector(num_axi_slaves * axi_id_bit_width - 1 downto 0);
     signal m_araddr  : std_logic_vector(num_axi_slaves * axi_addr_bits - 1 downto 0);
     signal m_arlen   : std_logic_vector(num_axi_slaves * axi_len_bits - 1 downto 0);
     signal m_arvalid : std_logic_vector(num_axi_slaves - 1 downto 0);
     signal m_rready  : std_logic_vector(num_axi_slaves - 1 downto 0);
     -- signal m_arsize   : std_logic_vector(num_axi_slaves * axi_burstsize_bits - 1 downto 0);
     -- signal m_arburst  : std_logic_vector(num_axi_slaves * axi_burstmode_bits - 1 downto 0);
     -- signal m_arlock   : std_logic_vector(num_axi_slaves - 1 downto 0);
     -- signal m_arcache  : std_logic_vector(num_axi_slaves * axi_cache_bits - 1 downto 0);
     -- signal m_arprot   : std_logic_vector(num_axi_slaves * axi_prot_bits - 1 downto 0);
     -- signal m_arqos    : std_logic_vector(num_axi_slaves * axi_qos_bits - 1 downto 0);
     -- signal m_awregion : std_logic_vector(num_axi_slaves * axi_id_bits - 1 downto 0);
     -- signal m_arregion : std_logic_vector(num_axi_slaves * axi_id_bits - 1 downto 0);
     signal s_axi_awlock  : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_awvalid : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_wlast   : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_wvalid  : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_bready  : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_arlock  : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_arvalid : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_rready  : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);

     signal s_axi_awready : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_wready  : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_bvalid  : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_arready : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_rlast   : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);
     signal s_axi_rvalid  : std_logic_vector(num_axi_slave_interfaces - 1 downto 0);

begin

     type_map: for slave_idx in 0 to i_hbm_write_out'length - 1 generate
          m_awready(slave_idx)                                                                <= i_hbm_write_out(slave_idx).awready;
          m_wready(slave_idx)                                                                 <= i_hbm_write_out(slave_idx).wready;
          m_bresp((slave_idx + 1) * axi_resp_bits - 1 downto slave_idx * axi_resp_bits)       <= i_hbm_write_out(slave_idx).bresp;
          m_bvalid(slave_idx)                                                                 <= i_hbm_write_out(slave_idx).bvalid;
          m_arready(slave_idx)                                                                <= i_hbm_read_out(slave_idx).arready;
          m_rdata((slave_idx + 1) * axi_pkg_bit_size - 1 downto slave_idx * axi_pkg_bit_size) <= i_hbm_read_out(slave_idx).rdata;
          m_rresp((slave_idx + 1) * axi_resp_bits - 1 downto slave_idx * axi_resp_bits)       <= i_hbm_read_out(slave_idx).rresp;
          m_rlast(slave_idx)                                                                  <= i_hbm_read_out(slave_idx).rlast;
          m_rvalid(slave_idx)                                                                 <= i_hbm_read_out(slave_idx).rvalid;

          o_hbm_write_in(slave_idx).awaddr  <= unsigned(m_awaddr((slave_idx + 1) * axi_addr_bits - 1 downto slave_idx * axi_addr_bits));
          o_hbm_write_in(slave_idx).awvalid <= m_awvalid(slave_idx);
          o_hbm_write_in(slave_idx).wdata   <= m_wdata((slave_idx + 1) * axi_pkg_bit_size - 1 downto slave_idx * axi_pkg_bit_size);
          o_hbm_write_in(slave_idx).wdata_parity <= (others=>'0'); -- outside of hbm axi expects does not expect parity bits
          -- i_hbm_read_out(slave_idx).rdata_parity <= open;
          o_hbm_write_in(slave_idx).wlast  <= m_wlast(slave_idx);
          o_hbm_write_in(slave_idx).wvalid <= m_wvalid(slave_idx);
          o_hbm_write_in(slave_idx).bready <= m_bready(slave_idx);

          o_hbm_read_in(slave_idx).araddr  <= unsigned(m_araddr((slave_idx + 1) * axi_addr_bits - 1 downto slave_idx * axi_addr_bits));
          o_hbm_read_in(slave_idx).arvalid <= m_arvalid(slave_idx);
          o_hbm_read_in(slave_idx).rready  <= m_rready(slave_idx);

          m_bid((slave_idx + 1) * axi_id_bit_width - 1 downto slave_idx * axi_id_bit_width) <= i_hbm_write_out(slave_idx).bid;
          m_rid((slave_idx + 1) * axi_id_bit_width - 1 downto slave_idx * axi_id_bit_width) <= i_hbm_read_out(slave_idx).rid;
          o_hbm_write_in(slave_idx).awid                                          <= m_awid((slave_idx + 1) * axi_id_bit_width - 1 downto slave_idx * axi_id_bit_width);
          o_hbm_read_in(slave_idx).arid                                           <= m_arid((slave_idx + 1) * axi_id_bit_width - 1 downto slave_idx * axi_id_bit_width);
          -- the burstlength is different length, need to convert
          o_hbm_write_in(slave_idx).awlen <= m_awlen((slave_idx + 1) * axi_len_bits - burstlen_pad_bits_length - 1 downto slave_idx * axi_len_bits);
          o_hbm_read_in(slave_idx).arlen  <= m_arlen((slave_idx + 1) * axi_len_bits - burstlen_pad_bits_length - 1 downto slave_idx * axi_len_bits);

          -- cannot set these, hbm only supports 1 value and outside modules should not think that they can influence it
          -- open <= m_awsize((slave_idx + 1) * axi_burstsize_bits - 1 downto slave_idx * axi_burstsize_bits);
          -- open <= m_awburst((slave_idx + 1) * axi_burstmode_bits - 1 downto slave_idx * axi_burstmode_bits);
          -- m_arsize((slave_idx + 1) * axi_burstsize_bits - 1 downto slave_idx * axi_burstsize_bits) <= open;
          -- m_arburst((slave_idx + 1) * axi_burstmode_bits - 1 downto slave_idx * axi_burstmode_bits) <= open;

          -- hbm cannot do anything with lock, cache, prot & qos and we are not using strobe
          -- open <= m_wstrb((slave_idx + 1) * axi_strobe_bits - 1 downto slave_idx * axi_strobe_bits);
          -- open <= m_awlock(slave_idx);
          -- open <= m_awcache((slave_idx + 1) * axi_cache_bits - 1 downto slave_idx * axi_cache_bits);
          -- open <= m_awprot((slave_idx + 1) * axi_prot_bits - 1 downto slave_idx * axi_prot_bits);
          -- open <= m_awqos((slave_idx + 1) * axi_aw_qos_bits - 1 downto slave_idx * axi_qos_bits);

          -- open <= m_arlock(slave_idx);
          -- open <= m_arcache((slave_idx + 1) * axi_cache_bits - 1 downto slave_idx * axi_cache_bits);
          -- open <= m_arprot((slave_idx + 1) * axi_prot_bits - 1 downto slave_idx * axi_prot_bits);
          -- open <= m_arqos((slave_idx + 1) * axi_aw_qos_bits - 1 downto slave_idx * axi_qos_bits);          
     end generate;

     one_bit_vector_to_std_logic_map: for master_idx in 0 to s_axi_awlock'length - 1 generate
          -- it is only one master
          s_axi_awlock(master_idx)  <= '0';
          s_axi_awvalid(master_idx) <= i_write_pkgs.crtl.addr_valid;
          s_axi_wlast(master_idx)   <= i_write_pkgs.last;
          s_axi_wvalid(master_idx)  <= i_write_pkgs.valid;
          s_axi_bready(master_idx)  <= i_write_pkgs.crtl.ready;
          s_axi_arlock(master_idx)  <= '0';
          s_axi_arvalid(master_idx) <= i_read_pkgs.crtl.addr_valid;
          s_axi_rready(master_idx)  <= i_read_pkgs.crtl.ready;

          o_write_pkgs.crtl.addr_ready <= s_axi_awready(master_idx);
          o_write_pkgs.ready      <= s_axi_wready(master_idx);
          o_write_pkgs.crtl.valid      <= s_axi_bvalid(master_idx);
          o_read_pkgs.crtl.addr_ready  <= s_axi_arready(master_idx);
          o_read_pkgs.last             <= s_axi_rlast(master_idx);
          o_read_pkgs.crtl.valid       <= s_axi_rvalid(master_idx);
     end generate;

     axi_crossbar_0_inst: axi_crossbar_0
          port map (
               aclk           => i_clk,
               aresetn        => i_reset_n,

               s_axi_awid     => i_write_pkgs.crtl.id,
               s_axi_awaddr   => i_write_pkgs.crtl.addr,
               s_axi_awlen    => i_write_pkgs.crtl.len,
               s_axi_awsize   => i_write_pkgs.crtl.size,
               s_axi_awburst  => i_write_pkgs.crtl.burst,
               s_axi_awlock   => s_axi_awlock,                         --i_write_pkgs.crtl.lock,
               s_axi_awcache  => i_write_pkgs.crtl.cache,
               s_axi_awprot   => i_write_pkgs.crtl.prot,
               s_axi_awqos    => i_write_pkgs.crtl.qos,
               s_axi_awvalid  => s_axi_awvalid,
               s_axi_bready   => s_axi_bready,

               s_axi_wvalid   => s_axi_wvalid,
               s_axi_wdata    => std_logic_vector(i_write_pkgs.data),
               s_axi_wstrb    => std_logic_vector(hbm_strobe_setting), --i_write_pkgs.strobe,
               s_axi_wlast    => s_axi_wlast,

               s_axi_arid     => i_read_pkgs.crtl.id,
               s_axi_araddr   => i_read_pkgs.crtl.addr,
               s_axi_arlen    => i_read_pkgs.crtl.len,
               s_axi_arsize   => i_read_pkgs.crtl.size,
               s_axi_arburst  => i_read_pkgs.crtl.burst,
               s_axi_arlock   => s_axi_arlock,                         --i_read_pkgs.crtl.lock,
               s_axi_arcache  => i_read_pkgs.crtl.cache,
               s_axi_arprot   => i_read_pkgs.crtl.prot,
               s_axi_arqos    => i_read_pkgs.crtl.qos,
               s_axi_arvalid  => s_axi_arvalid,
               s_axi_rready   => s_axi_rready,
               m_axi_awready  => m_awready,
               m_axi_bid      => m_bid,
               m_axi_bresp    => m_bresp,
               m_axi_bvalid   => m_bvalid,
               m_axi_wready   => m_wready,
               m_axi_arready  => m_arready,
               m_axi_rid      => m_rid,
               m_axi_rresp    => m_rresp,
               m_axi_rvalid   => m_rvalid,
               m_axi_rlast    => m_rlast,
               m_axi_rdata    => m_rdata,

               s_axi_awready  => s_axi_awready,
               s_axi_wready   => s_axi_wready,
               s_axi_bid      => o_write_pkgs.crtl.id,
               s_axi_bresp    => o_write_pkgs.crtl.resp,
               s_axi_bvalid   => s_axi_bvalid,
               s_axi_arready  => s_axi_arready,
               s_axi_rid      => o_read_pkgs.crtl.id,
               s_axi_rdata    => o_read_pkgs.data,
               s_axi_rresp    => o_read_pkgs.crtl.resp,
               s_axi_rlast    => s_axi_rlast,
               s_axi_rvalid   => s_axi_rvalid,

               m_axi_awid     => m_awid,
               m_axi_awaddr   => m_awaddr,
               m_axi_awlen    => m_awlen,
               m_axi_awsize   => open,                                 --m_awsize,
               m_axi_awburst  => open,                                 --m_awburst,
               m_axi_awlock   => open,                                 --m_awlock,
               m_axi_awcache  => open,                                 --m_awcache,
               m_axi_awprot   => open,                                 --m_awprot,
               m_axi_awqos    => open,                                 --m_awqos,
               m_axi_awvalid  => m_awvalid,
               m_axi_wdata    => m_wdata,
               m_axi_wstrb    => open,                                 --m_wstrb,
               m_axi_wlast    => m_wlast,
               m_axi_wvalid   => m_wvalid,
               m_axi_bready   => m_bready,
               m_axi_arid     => m_arid,
               m_axi_araddr   => m_araddr,
               m_axi_arlen    => m_arlen,
               m_axi_arsize   => open,                                 --m_arsize,
               m_axi_arburst  => open,                                 --m_arburst,
               m_axi_arlock   => open,                                 --m_arlock,
               m_axi_arcache  => open,                                 --m_arcache,
               m_axi_arprot   => open,                                 --m_arprot,
               m_axi_arqos    => open,                                 --m_arqos,
               m_axi_arvalid  => m_arvalid,
               m_axi_rready   => m_rready,
               m_axi_awregion => open,                                 --m_awregion,
               m_axi_arregion => open --m_arregion
          );
end architecture;
