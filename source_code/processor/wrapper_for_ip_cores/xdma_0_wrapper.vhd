----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: xdma_0_wrapper
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
     use work.constants_utils.all;
     use work.ip_cores_constants.all;
     use work.processor_utils.all;

entity xdma_0_wrapper is
     port (
          i_sys_clk                    : in  std_ulogic; -- should be 250 MHz
          i_sys_clk_gt                 : in  std_ulogic; -- should be riven from the O port of reference clock IBUFDS_GTE3
          i_reset_n                : in  std_ulogic;

          axi_master_write_out     : in  axi_out_write_pkg;
          axi_master_read_out      : in  axi_out_read_pkg;
          axi_master_write_in      : out axi_in_write_pkg;
          axi_master_read_in       : out axi_in_read_pkg;

          pci_exp_rxp              : in  std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
          pci_exp_rxn              : in  std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
          pci_exp_txp              : out std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
          pci_exp_txn              : out std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);

          -- cfg_mgmt_addr            : in  std_logic_vector(pcie_cfg_mgmt_addr_bit_width - 1 downto 0);
          -- cfg_mgmt_write           : in  std_logic;
          -- cfg_mgmt_write_data      : in  std_logic_vector(pcie_cfg_mgmt_data_bit_width - 1 downto 0);
          -- cfg_mgmt_byte_enable     : in  std_logic_vector(pcie_cfg_byte_enable_bit_width - 1 downto 0);
          -- cfg_mgmt_read            : in  std_logic;
          -- cfg_mgmt_read_data       : out std_logic_vector(pcie_cfg_mgmt_data_bit_width - 1 downto 0);
          -- cfg_mgmt_read_write_done : out std_logic;

          o_axi_clk                : out std_ulogic;
          o_axi_reset_n            : out std_ulogic
     );
end entity;

architecture Behavioral of xdma_0_wrapper is

     component xdma_0 is
          port (
               sys_clk                  : in  std_logic;
               sys_clk_gt               : in  std_logic;
               sys_rst_n                : in  std_logic;
               pci_exp_rxp              : in  std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
               pci_exp_rxn              : in  std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
               usr_irq_req              : in  std_logic_vector(pcie_irq_bit_width - 1 downto 0);
               m_axi_awready            : in  std_logic;
               m_axi_wready             : in  std_logic;
               m_axi_bid                : in  std_logic_vector(pcie_id_bit_width - 1 downto 0);
               m_axi_bresp              : in  std_logic_vector(pcie_resp_bit_width - 1 downto 0);
               m_axi_bvalid             : in  std_logic;
               m_axi_arready            : in  std_logic;
               m_axi_rdata              : in  std_logic_vector(pcie_data_bit_width - 1 downto 0);
               m_axi_rid                : in  std_logic_vector(pcie_id_bit_width - 1 downto 0);
               m_axi_rresp              : in  std_logic_vector(pcie_resp_bit_width - 1 downto 0);
               m_axi_rlast              : in  std_logic;
               m_axi_rvalid             : in  std_logic;
               -- cfg_mgmt_addr            : in  std_logic_vector(pcie_cfg_mgmt_addr_bit_width - 1 downto 0);
               -- cfg_mgmt_write           : in  std_logic;
               -- cfg_mgmt_write_data      : in  std_logic_vector(pcie_cfg_mgmt_data_bit_width - 1 downto 0);
               -- cfg_mgmt_byte_enable     : in  std_logic_vector(pcie_cfg_byte_enable_bit_width - 1 downto 0);
               -- cfg_mgmt_read            : in  std_logic;

               user_lnk_up              : out std_logic;
               pci_exp_txp              : out std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
               pci_exp_txn              : out std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
               axi_aclk                 : out std_logic;
               axi_aresetn              : out std_logic;
               usr_irq_ack              : out std_logic_vector(pcie_irq_bit_width - 1 downto 0);
               -- msi_enable               : out std_logic;
               -- msi_vector_width         : out std_logic_vector(pcie_msi_vec_width_bit_width - 1 downto 0);
               m_axi_awid               : out std_logic_vector(pcie_id_bit_width - 1 downto 0);
               m_axi_awaddr             : out std_logic_vector(pcie_addr_bit_width - 1 downto 0);
               m_axi_awlen              : out std_logic_vector(axi_len_bits - 1 downto 0);
               m_axi_awsize             : out std_logic_vector(axi_burstsize_bits - 1 downto 0);
               m_axi_awburst            : out std_logic_vector(axi_burstmode_bits - 1 downto 0);
               m_axi_awprot             : out std_logic_vector(axi_prot_bits - 1 downto 0);
               m_axi_awvalid            : out std_logic;
               m_axi_awlock             : out std_logic;
               m_axi_awcache            : out std_logic_vector(axi_cache_bits - 1 downto 0);
               m_axi_wdata              : out std_logic_vector(axi_pkg_bit_size - 1 downto 0);
               m_axi_wstrb              : out std_logic_vector(axi_strobe_bits - 1 downto 0);
               m_axi_wlast              : out std_logic;
               m_axi_wvalid             : out std_logic;
               m_axi_bready             : out std_logic;
               m_axi_arid               : out std_logic_vector(pcie_id_bit_width - 1 downto 0);
               m_axi_araddr             : out std_logic_vector(pcie_addr_bit_width - 1 downto 0);
               m_axi_arlen              : out std_logic_vector(axi_len_bits - 1 downto 0);
               m_axi_arsize             : out std_logic_vector(axi_burstsize_bits - 1 downto 0);
               m_axi_arburst            : out std_logic_vector(axi_burstmode_bits - 1 downto 0);
               m_axi_arprot             : out std_logic_vector(axi_prot_bits - 1 downto 0);
               m_axi_arvalid            : out std_logic;
               m_axi_arlock             : out std_logic;
               m_axi_arcache            : out std_logic_vector(axi_cache_bits - 1 downto 0);
               m_axi_rready             : out std_logic--;
               -- cfg_mgmt_read_data       : out std_logic_vector(pcie_cfg_mgmt_data_bit_width - 1 downto 0);
               -- cfg_mgmt_read_write_done : out std_logic
          );
     end component;

     signal usr_irq_req: std_logic_vector(pcie_irq_bit_width - 1 downto 0);
     signal m_axi_awaddr: std_logic_vector(pcie_addr_bit_width-1 downto 0);
     signal m_axi_araddr: std_logic_vector(pcie_addr_bit_width-1 downto 0);
     signal m_axi_awid: std_logic_vector(pcie_id_bit_width-1 downto 0);
     signal m_axi_arid: std_logic_vector(pcie_id_bit_width-1 downto 0);

begin
     
     usr_irq_req <= (others => '0');
     axi_master_write_in.crtl.addr <= m_axi_awaddr(axi_master_write_in.crtl.addr'length-1 downto 0);
     axi_master_read_in.crtl.addr <= m_axi_araddr(axi_master_read_in.crtl.addr'length-1 downto 0);

     -- axi_id_bit_width=hbm_id_bit_width=6 but xdma_id_bit_width=4 --> need to convert
     axi_master_write_in.crtl.id <= id_pad_bits & m_axi_awid;
     axi_master_read_in.crtl.id <= id_pad_bits & m_axi_arid;
     axi_master_read_in.crtl.qos <= (others => '0');
     axi_master_write_in.crtl.qos <= (others => '0');

     xdma_0_wrapper_inst: xdma_0
          port map (
               sys_clk                  => i_sys_clk,
               sys_clk_gt               => i_sys_clk_gt,
               sys_rst_n                => i_reset_n,
               pci_exp_rxp              => pci_exp_rxp,
               pci_exp_rxn              => pci_exp_rxn,
               usr_irq_req              => usr_irq_req,   -- assert to generate an interrupt
               m_axi_awready            => axi_master_write_out.crtl.addr_ready,
               m_axi_wready             => axi_master_write_out.ready,
               m_axi_bid                => axi_master_write_out.crtl.id(pcie_id_bit_width-1 downto 0),
               m_axi_bresp              => axi_master_write_out.crtl.resp,
               m_axi_bvalid             => axi_master_write_out.crtl.valid,
               m_axi_arready            => axi_master_read_out.crtl.addr_ready,
               m_axi_rdata              => axi_master_read_out.data,
               m_axi_rid                => axi_master_read_out.crtl.id(pcie_id_bit_width-1 downto 0),
               m_axi_rresp              => axi_master_read_out.crtl.resp,
               m_axi_rlast              => axi_master_read_out.last,
               m_axi_rvalid             => axi_master_read_out.crtl.valid,
               -- cfg_mgmt_addr            => cfg_mgmt_addr,
               -- cfg_mgmt_write           => cfg_mgmt_write,
               -- cfg_mgmt_write_data      => cfg_mgmt_write_data,
               -- cfg_mgmt_byte_enable     => cfg_mgmt_byte_enable,
               -- cfg_mgmt_read            => cfg_mgmt_read,
               -- outputs
               user_lnk_up              => open,  -- shows that pcie linked with a host device
               pci_exp_txp              => pci_exp_txp,
               pci_exp_txn              => pci_exp_txn,
               axi_aclk                 => o_axi_clk,
               axi_aresetn              => o_axi_reset_n,
               usr_irq_ack              => open,  -- indicates that interrupt has been send to pcie
               -- msi_enable               => open,  -- msi is for interrups, we should not need them here
               -- msi_vector_width         => open,  -- msi is for interrups, we should not need them here
               m_axi_awid               => m_axi_awid,
               m_axi_awaddr             => m_axi_awaddr,
               m_axi_awlen              => axi_master_write_in.crtl.len,
               m_axi_awsize             => axi_master_write_in.crtl.size,
               m_axi_awburst            => axi_master_write_in.crtl.burst,
               m_axi_awprot             => axi_master_write_in.crtl.prot,
               m_axi_awvalid            => axi_master_write_in.crtl.addr_valid,
               m_axi_awlock             => open,  -- no lock function
               m_axi_awcache            => axi_master_write_in.crtl.cache,
               m_axi_wdata              => axi_master_write_in.data,
               m_axi_wstrb              => axi_master_write_in.strobe,
               m_axi_wlast              => axi_master_write_in.last,
               m_axi_wvalid             => axi_master_write_in.valid,
               m_axi_bready             => axi_master_write_in.crtl.ready,
               m_axi_arid               => m_axi_arid,
               m_axi_araddr             => m_axi_araddr,
               m_axi_arlen              => axi_master_read_in.crtl.len,
               m_axi_arsize             => axi_master_read_in.crtl.size,
               m_axi_arburst            => axi_master_read_in.crtl.burst,
               m_axi_arprot             => axi_master_read_in.crtl.prot,
               m_axi_arvalid            => axi_master_read_in.crtl.addr_valid,
               m_axi_arlock             => open,  -- no lock function
               m_axi_arcache            => axi_master_read_in.crtl.cache,
               m_axi_rready             => axi_master_read_in.crtl.ready--,
               -- cfg_mgmt_read_data       => cfg_mgmt_read_data,
               -- cfg_mgmt_read_write_done => cfg_mgmt_read_write_done
          );
end architecture;
