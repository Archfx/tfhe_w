----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: pcie4c_uscale_plus_0
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

entity pcie4c_uscale_plus_0_wrapper is
     port (
          i_sys_clk    : in  std_ulogic; -- 250 MHz
          i_sys_clk_gt : in  std_ulogic; --This clock must be driven directly from IBUFDS_GTE (same definition and frequency as sys_clk)
          i_reset_n    : in  std_ulogic;
          pci_exp_rxp  : in  std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
          pci_exp_rxn  : in  std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
          pci_exp_txp  : out std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
          pci_exp_txn  : out std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0)
               -- all the other relevant in-outputs are to be handled by constraints
     );
end entity;

architecture Behavioral of pcie4c_uscale_plus_0_wrapper is

     component pcie4c_uscale_plus_0 is
          port (
               pci_exp_rxn                      : in  std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
               pci_exp_rxp                      : in  std_logic_vector(pcie_rx_tx_bit_width - 1 downto 0);
               s_axis_rq_tdata                  : in  std_logic_vector(pcie_data_bit_width - 1 downto 0);
               s_axis_rq_tkeep                  : in  std_logic_vector(pcie_tkeep_bit_width - 1 downto 0);
               s_axis_rq_tlast                  : in  std_logic;
               s_axis_rq_tuser                  : in  std_logic_vector(pcie_rq_tuser_bit_width - 1 downto 0);
               s_axis_rq_tvalid                 : in  std_logic;
               m_axis_rc_tready                 : in  std_logic;
               m_axis_cq_tready                 : in  std_logic;
               s_axis_cc_tdata                  : in  std_logic_vector(pcie_data_bit_width - 1 downto 0);
               s_axis_cc_tkeep                  : in  std_logic_vector(pcie_tkeep_bit_width - 1 downto 0);
               s_axis_cc_tlast                  : in  std_logic;
               s_axis_cc_tuser                  : in  std_logic_vector(pcie_rq_cc_tuser_bit_width - 1 downto 0);
               s_axis_cc_tvalid                 : in  std_logic;
               pcie_cq_np_req                   : in  std_logic_vector(pcie_cp_np_bit_width - 1 downto 0);
               cfg_mgmt_addr                    : in  std_logic_vector(10 - 1 downto 0);
               cfg_mgmt_function_number         : in  std_logic_vector(8 - 1 downto 0);
               cfg_mgmt_write                   : in  std_logic;
               cfg_mgmt_write_data              : in  std_logic_vector(pcie_cfg_mgmt_data_bit_width - 1 downto 0);
               cfg_mgmt_byte_enable             : in  std_logic_vector(pcie_cfg_byte_enable_bit_width - 1 downto 0);
               cfg_mgmt_read                    : in  std_logic;
               cfg_mgmt_debug_access            : in  std_logic;
               cfg_msg_transmit                 : in  std_logic;
               cfg_msg_transmit_type            : in  std_logic_vector(3 - 1 downto 0);
               cfg_msg_transmit_data            : in  std_logic_vector(pcie_cfg_mgmt_data_bit_width - 1 downto 0);
               cfg_fc_sel                       : in  std_logic_vector(3 - 1 downto 0);
               cfg_dsn                          : in  std_logic_vector(64 - 1 downto 0);
               cfg_power_state_change_ack       : in  std_logic;
               cfg_err_uncor_in                 : in  std_logic;
               cfg_flr_done                     : in  std_logic_vector(4 - 1 downto 0);
               cfg_vf_flr_func_num              : in  std_logic_vector(8 - 1 downto 0);
               cfg_vf_flr_done                  : in  std_logic_vector(1 - 1 downto 0);
               cfg_link_training_enable         : in  std_logic;
               cfg_interrupt_int                : in  std_logic_vector(4 - 1 downto 0);
               cfg_interrupt_pending            : in  std_logic_vector(4 - 1 downto 0);
               -- cfg_interrupt_msi_select                      : in  std_logic_vector(2 - 1 downto 0);
               -- cfg_interrupt_msi_int                         : in  std_logic_vector(32 - 1 downto 0);
               -- cfg_interrupt_msi_pending_status              : in  std_logic_vector(32 - 1 downto 0);
               -- cfg_interrupt_msi_pending_status_data_enable  : in  std_logic;
               -- cfg_interrupt_msi_pending_status_function_num : in  std_logic_vector(2 - 1 downto 0);
               -- cfg_interrupt_msi_attr                        : in  std_logic_vector(3 - 1 downto 0);
               -- cfg_interrupt_msi_tph_present                 : in  std_logic;
               -- cfg_interrupt_msi_tph_type                    : in  std_logic_vector(2 - 1 downto 0);
               -- cfg_interrupt_msi_tph_st_tag                  : in  std_logic_vector(8 - 1 downto 0);
               -- cfg_interrupt_msi_function_number             : in  std_logic_vector(8 - 1 downto 0);
               cfg_pm_aspm_l1_entry_reject      : in  std_logic;
               cfg_pm_aspm_tx_l0s_entry_disable : in  std_logic;
               cfg_config_space_enable          : in  std_logic;
               cfg_req_pm_transition_l23_ready  : in  std_logic;
               cfg_hot_reset_in                 : in  std_logic;
               cfg_ds_port_number               : in  std_logic_vector(8 - 1 downto 0);
               cfg_ds_bus_number                : in  std_logic_vector(8 - 1 downto 0);
               cfg_ds_device_number             : in  std_logic_vector(5 - 1 downto 0);
               cfg_err_cor_in                   : in  std_logic;
               sys_clk                          : in  std_logic;
               sys_clk_gt                       : in  std_logic;
               sys_reset                        : in  std_logic;

               pci_exp_txn                      : out std_logic_vector(4 - 1 downto 0);
               pci_exp_txp                      : out std_logic_vector(4 - 1 downto 0);
               s_axis_rq_tready                 : out std_logic_vector(4 - 1 downto 0);
               m_axis_rc_tdata                  : out std_logic_vector(pcie_data_bit_width - 1 downto 0);
               m_axis_rc_tkeep                  : out std_logic_vector(8 - 1 downto 0);
               m_axis_rc_tuser                  : out std_logic_vector(75 - 1 downto 0);
               m_axis_cq_tdata                  : out std_logic_vector(pcie_data_bit_width - 1 downto 0);
               m_axis_cq_tkeep                  : out std_logic_vector(8 - 1 downto 0);
               m_axis_cq_tuser                  : out std_logic_vector(88 - 1 downto 0);
               s_axis_cc_tready                 : out std_logic_vector(4 - 1 downto 0);
               pcie_rq_seq_num0                 : out std_logic_vector(6 - 1 downto 0);
               pcie_rq_seq_num1                 : out std_logic_vector(6 - 1 downto 0);
               pcie_rq_tag0                     : out std_logic_vector(8 - 1 downto 0);
               pcie_rq_tag1                     : out std_logic_vector(8 - 1 downto 0);
               pcie_rq_tag_av                   : out std_logic_vector(4 - 1 downto 0);
               pcie_tfc_nph_av                  : out std_logic_vector(4 - 1 downto 0);
               pcie_tfc_npd_av                  : out std_logic_vector(4 - 1 downto 0);
               pcie_cq_np_req_count             : out std_logic_vector(6 - 1 downto 0);
               cfg_phy_link_status              : out std_logic_vector(2 - 1 downto 0);
               cfg_negotiated_width             : out std_logic_vector(3 - 1 downto 0);
               cfg_current_speed                : out std_logic_vector(2 - 1 downto 0);
               cfg_max_payload                  : out std_logic_vector(2 - 1 downto 0);
               cfg_max_read_req                 : out std_logic_vector(3 - 1 downto 0);
               cfg_function_status              : out std_logic_vector(16 - 1 downto 0);
               cfg_function_power_state         : out std_logic_vector(12 - 1 downto 0);
               cfg_vf_status                    : out std_logic_vector(504 - 1 downto 0);
               cfg_vf_power_state               : out std_logic_vector(756 - 1 downto 0);
               cfg_link_power_state             : out std_logic_vector(2 - 1 downto 0);
               cfg_mgmt_read_data               : out std_logic_vector(32 - 1 downto 0);
               cfg_local_error_out              : out std_logic_vector(5 - 1 downto 0);
               cfg_ltssm_state                  : out std_logic_vector(6 - 1 downto 0);
               cfg_rx_pm_state                  : out std_logic_vector(2 - 1 downto 0);
               cfg_tx_pm_state                  : out std_logic_vector(2 - 1 downto 0);
               cfg_rcb_status                   : out std_logic_vector(4 - 1 downto 0);
               cfg_obff_enable                  : out std_logic_vector(2 - 1 downto 0);
               cfg_tph_requester_enable         : out std_logic_vector(4 - 1 downto 0);
               cfg_tph_st_mode                  : out std_logic_vector(12 - 1 downto 0);
               cfg_vf_tph_requester_enable      : out std_logic_vector(252 - 1 downto 0);
               cfg_vf_tph_st_mode               : out std_logic_vector(756 - 1 downto 0);
               cfg_msg_received_data            : out std_logic_vector(8 - 1 downto 0);
               cfg_msg_received_type            : out std_logic_vector(5 - 1 downto 0);
               cfg_fc_ph                        : out std_logic_vector(8 - 1 downto 0);
               cfg_fc_pd                        : out std_logic_vector(12 - 1 downto 0);
               cfg_fc_nph                       : out std_logic_vector(8 - 1 downto 0);
               cfg_fc_npd                       : out std_logic_vector(12 - 1 downto 0);
               cfg_fc_cplh                      : out std_logic_vector(8 - 1 downto 0);
               cfg_fc_cpld                      : out std_logic_vector(12 - 1 downto 0);
               cfg_bus_number                   : out std_logic_vector(8 - 1 downto 0);
               cfg_flr_in_process               : out std_logic_vector(4 - 1 downto 0);
               cfg_vf_flr_in_process            : out std_logic_vector(252 - 1 downto 0);
               -- cfg_interrupt_msi_enable                      : out std_logic_vector(4 - 1 downto 0);
               -- cfg_interrupt_msi_mmenable                    : out std_logic_vector(12 - 1 downto 0);
               -- cfg_interrupt_msi_data                        : out std_logic_vector(32 - 1 downto 0);
               -- cfg_interrupt_msi_sent                        : out std_logic;
               -- cfg_interrupt_msi_mask_update                 : out std_logic;
               cfg_interrupt_sent               : out std_logic;
               cfg_power_state_change_interrupt : out std_logic;
               cfg_msg_transmit_done            : out std_logic;
               cfg_msg_received                 : out std_logic;
               cfg_pl_status_change             : out std_logic;
               cfg_local_error_valid            : out std_logic;
               cfg_err_fatal_out                : out std_logic;
               cfg_err_nonfatal_out             : out std_logic;
               cfg_err_cor_out                  : out std_logic;
               cfg_mgmt_read_write_done         : out std_logic;
               cfg_phy_link_down                : out std_logic;
               pcie_rq_tag_vld1                 : out std_logic;
               pcie_rq_tag_vld0                 : out std_logic;
               pcie_rq_seq_num_vld1             : out std_logic;
               pcie_rq_seq_num_vld0             : out std_logic;
               m_axis_cq_tvalid                 : out std_logic;
               m_axis_cq_tlast                  : out std_logic;
               m_axis_rc_tvalid                 : out std_logic;
               m_axis_rc_tlast                  : out std_logic;
               user_lnk_up                      : out std_logic;
               user_reset                       : out std_logic;
               user_clk                         : out std_logic;
               -- cfg_interrupt_msi_fail                        : out std_logic;
               cfg_hot_reset_out                : out std_logic;
               phy_rdy_out                      : out std_logic
          );
     end component;

     signal s_axis_rq_tdata            : std_logic_vector(pcie_data_bit_width - 1 downto 0)            := (others => '0');
     signal s_axis_rq_tkeep            : std_logic_vector(pcie_tkeep_bit_width - 1 downto 0)           := (others => '0');
     signal s_axis_rq_tlast            : std_logic                                                     := '0';
     signal s_axis_rq_tuser            : std_logic_vector(pcie_rq_tuser_bit_width - 1 downto 0)        := (others => '0');
     signal s_axis_rq_tvalid           : std_logic                                                     := '0';
     signal m_axis_rc_tready           : std_logic                                                     := '0';
     signal m_axis_cq_tready           : std_logic                                                     := '0';
     signal s_axis_cc_tdata            : std_logic_vector(pcie_data_bit_width - 1 downto 0)            := (others => '0');
     signal s_axis_cc_tkeep            : std_logic_vector(pcie_tkeep_bit_width - 1 downto 0)           := (others => '0');
     signal s_axis_cc_tlast            : std_logic                                                     := '0';
     signal s_axis_cc_tuser            : std_logic_vector(pcie_rq_cc_tuser_bit_width - 1 downto 0)     := (others => '0');
     signal s_axis_cc_tvalid           : std_logic                                                     := '0';
     signal pcie_cq_np_req             : std_logic_vector(pcie_cp_np_bit_width - 1 downto 0)           := (others => '0');
     signal cfg_mgmt_addr              : std_logic_vector(10 - 1 downto 0)                             := (others => '0');
     signal cfg_mgmt_function_number   : std_logic_vector(8 - 1 downto 0)                              := (others => '0');
     signal cfg_mgmt_write             : std_logic                                                     := '0';
     signal cfg_mgmt_write_data        : std_logic_vector(pcie_cfg_mgmt_data_bit_width - 1 downto 0)   := (others => '0');
     signal cfg_mgmt_byte_enable       : std_logic_vector(pcie_cfg_byte_enable_bit_width - 1 downto 0) := (others => '0');
     signal cfg_mgmt_read              : std_logic                                                     := '0';
     signal cfg_mgmt_debug_access      : std_logic                                                     := '0';
     signal cfg_msg_transmit           : std_logic                                                     := '0';
     signal cfg_msg_transmit_type      : std_logic_vector(3 - 1 downto 0)                              := (others => '0');
     signal cfg_msg_transmit_data      : std_logic_vector(pcie_cfg_mgmt_data_bit_width - 1 downto 0)   := (others => '0');
     signal cfg_fc_sel                 : std_logic_vector(3 - 1 downto 0)                              := (others => '0');
     signal cfg_dsn                    : std_logic_vector(64 - 1 downto 0)                             := (others => '0');
     signal cfg_power_state_change_ack : std_logic                                                     := '0';
     signal cfg_err_uncor_in           : std_logic                                                     := '0';
     signal cfg_flr_done               : std_logic_vector(4 - 1 downto 0)                              := (others => '0');
     signal cfg_vf_flr_func_num        : std_logic_vector(8 - 1 downto 0)                              := (others => '0');
     signal cfg_vf_flr_done            : std_logic_vector(1 - 1 downto 0)                              := (others => '0');
     signal cfg_link_training_enable   : std_logic                                                     := '0';
     signal cfg_interrupt_int          : std_logic_vector(4 - 1 downto 0)                              := (others => '0');
     signal cfg_interrupt_pending      : std_logic_vector(4 - 1 downto 0)                              := (others => '0');
     -- signal cfg_interrupt_msi_select                      : std_logic_vector(2 - 1 downto 0) :=                          (others => '0');
     -- signal cfg_interrupt_msi_int                         : std_logic_vector(32 - 1 downto 0) :=                         (others => '0');
     -- signal cfg_interrupt_msi_pending_status              : std_logic_vector(32 - 1 downto 0) :=                         (others => '0');
     -- signal cfg_interrupt_msi_pending_status_data_enable  : std_logic := '0';
     -- signal cfg_interrupt_msi_pending_status_function_num : std_logic_vector(2 - 1 downto 0) :=                          (others => '0');
     -- signal cfg_interrupt_msi_attr                        : std_logic_vector(3 - 1 downto 0) :=                          (others => '0');
     -- signal cfg_interrupt_msi_tph_present                 : std_logic := '0';
     -- signal cfg_interrupt_msi_tph_type                    : std_logic_vector(2 - 1 downto 0) :=                          (others => '0');
     -- signal cfg_interrupt_msi_tph_st_tag                  : std_logic_vector(8 - 1 downto 0) :=                          (others => '0');
     -- signal cfg_interrupt_msi_function_number             : std_logic_vector(8 - 1 downto 0) :=                          (others => '0');
     signal cfg_pm_aspm_l1_entry_reject      : std_logic                        := '0';
     signal cfg_pm_aspm_tx_l0s_entry_disable : std_logic                        := '0';
     signal cfg_config_space_enable          : std_logic                        := '0';
     signal cfg_req_pm_transition_l23_ready  : std_logic                        := '0';
     signal cfg_hot_reset_in                 : std_logic                        := '0';
     signal cfg_err_cor_in                   : std_logic                        := '0';
     signal cfg_ds_port_number               : std_logic_vector(8 - 1 downto 0) := (others => '0');
     signal cfg_ds_bus_number                : std_logic_vector(8 - 1 downto 0) := (others => '0');
     signal cfg_ds_device_number             : std_logic_vector(5 - 1 downto 0) := (others => '0');

begin

     pcie4c_uscale_plus_0_inst: pcie4c_uscale_plus_0
          port map (
               pci_exp_rxn                      => pci_exp_rxn,
               pci_exp_rxp                      => pci_exp_rxp,
               -- xdma only provides rx and tx signals, no idea how to use all these other signals
               s_axis_rq_tdata                  => s_axis_rq_tdata,
               s_axis_rq_tkeep                  => s_axis_rq_tkeep,
               s_axis_rq_tlast                  => s_axis_rq_tlast,
               s_axis_rq_tuser                  => s_axis_rq_tuser,
               s_axis_rq_tvalid                 => s_axis_rq_tvalid,
               m_axis_rc_tready                 => m_axis_rc_tready,
               m_axis_cq_tready                 => m_axis_cq_tready,
               s_axis_cc_tdata                  => s_axis_cc_tdata,
               s_axis_cc_tkeep                  => s_axis_cc_tkeep,
               s_axis_cc_tlast                  => s_axis_cc_tlast,
               s_axis_cc_tuser                  => s_axis_cc_tuser,
               s_axis_cc_tvalid                 => s_axis_cc_tvalid,
               pcie_cq_np_req                   => pcie_cq_np_req,
               cfg_mgmt_addr                    => cfg_mgmt_addr,
               cfg_mgmt_function_number         => cfg_mgmt_function_number,
               cfg_mgmt_write                   => cfg_mgmt_write,
               cfg_mgmt_write_data              => cfg_mgmt_write_data,
               cfg_mgmt_byte_enable             => cfg_mgmt_byte_enable,
               cfg_mgmt_read                    => cfg_mgmt_read,
               cfg_mgmt_debug_access            => cfg_mgmt_debug_access,
               cfg_msg_transmit                 => cfg_msg_transmit,
               cfg_msg_transmit_type            => cfg_msg_transmit_type,
               cfg_msg_transmit_data            => cfg_msg_transmit_data,
               cfg_fc_sel                       => cfg_fc_sel,
               cfg_dsn                          => cfg_dsn,
               cfg_power_state_change_ack       => cfg_power_state_change_ack,
               cfg_err_uncor_in                 => cfg_err_uncor_in,
               cfg_flr_done                     => cfg_flr_done,
               cfg_vf_flr_func_num              => cfg_vf_flr_func_num,
               cfg_vf_flr_done                  => cfg_vf_flr_done,
               cfg_link_training_enable         => cfg_link_training_enable,
               cfg_interrupt_int                => cfg_interrupt_int,
               cfg_interrupt_pending            => cfg_interrupt_pending,
               -- cfg_interrupt_msi_select                      => cfg_interrupt_msi_select,
               -- cfg_interrupt_msi_int                         => cfg_interrupt_msi_int,
               -- cfg_interrupt_msi_pending_status              => cfg_interrupt_msi_pending_status,
               -- cfg_interrupt_msi_pending_status_data_enable  => '0',       --,cfg_interrupt_msi_pending_status_data_enable
               -- cfg_interrupt_msi_pending_status_function_num => cfg_interrupt_msi_pending_status_function_num,
               -- cfg_interrupt_msi_attr                        => cfg_interrupt_msi_attr,
               -- cfg_interrupt_msi_tph_present                 => '0',       --,cfg_interrupt_msi_tph_present
               -- cfg_interrupt_msi_tph_type                    => cfg_interrupt_msi_tph_type,
               -- cfg_interrupt_msi_tph_st_tag                  => cfg_interrupt_msi_tph_st_tag,
               -- cfg_interrupt_msi_function_number             => cfg_interrupt_msi_function_number,
               cfg_pm_aspm_l1_entry_reject      => cfg_pm_aspm_l1_entry_reject,
               cfg_pm_aspm_tx_l0s_entry_disable => cfg_pm_aspm_tx_l0s_entry_disable,
               cfg_config_space_enable          => cfg_config_space_enable,
               cfg_req_pm_transition_l23_ready  => cfg_req_pm_transition_l23_ready,
               cfg_hot_reset_in                 => cfg_hot_reset_in,
               cfg_ds_port_number               => cfg_ds_port_number,
               cfg_ds_bus_number                => cfg_ds_bus_number,
               cfg_ds_device_number             => cfg_ds_device_number,
               cfg_err_cor_in                   => cfg_err_cor_in,
               sys_clk                          => i_sys_clk,
               sys_clk_gt                       => i_sys_clk_gt,
               sys_reset                        => i_reset_n, -- sys_reset is active low

               pci_exp_txn                      => pci_exp_txn,
               pci_exp_txp                      => pci_exp_txp,
               s_axis_rq_tready                 => open,
               m_axis_rc_tdata                  => open,      -- our applications does not request data via pcie
               m_axis_rc_tkeep                  => open,
               m_axis_rc_tuser                  => open,
               m_axis_cq_tdata                  => open,
               m_axis_cq_tkeep                  => open,
               m_axis_cq_tuser                  => open,
               s_axis_cc_tready                 => open,
               pcie_rq_seq_num0                 => open,
               pcie_rq_seq_num1                 => open,
               pcie_rq_tag0                     => open,
               pcie_rq_tag1                     => open,
               pcie_rq_tag_av                   => open,
               pcie_tfc_nph_av                  => open,
               pcie_tfc_npd_av                  => open,
               pcie_cq_np_req_count             => open,
               cfg_phy_link_status              => open,
               cfg_negotiated_width             => open,
               cfg_current_speed                => open,
               cfg_max_payload                  => open,
               cfg_max_read_req                 => open,
               cfg_function_status              => open,
               cfg_function_power_state         => open,
               cfg_vf_status                    => open,
               cfg_vf_power_state               => open,
               cfg_link_power_state             => open,
               cfg_mgmt_read_data               => open,
               cfg_local_error_out              => open,
               cfg_ltssm_state                  => open,
               cfg_rx_pm_state                  => open,
               cfg_tx_pm_state                  => open,
               cfg_rcb_status                   => open,
               cfg_obff_enable                  => open,
               cfg_tph_requester_enable         => open,
               cfg_tph_st_mode                  => open,
               cfg_vf_tph_requester_enable      => open,
               cfg_vf_tph_st_mode               => open,
               cfg_msg_received_data            => open,
               cfg_msg_received_type            => open,
               cfg_fc_ph                        => open,
               cfg_fc_pd                        => open,
               cfg_fc_nph                       => open,
               cfg_fc_npd                       => open,
               cfg_fc_cplh                      => open,
               cfg_fc_cpld                      => open,
               cfg_bus_number                   => open,
               cfg_flr_in_process               => open,
               cfg_vf_flr_in_process            => open,
               -- cfg_interrupt_msi_enable                      => open,
               -- cfg_interrupt_msi_mmenable                    => open,
               -- cfg_interrupt_msi_data                        => open,
               -- cfg_interrupt_msi_sent                        => open,
               -- cfg_interrupt_msi_mask_update                 => open,
               cfg_interrupt_sent               => open,
               cfg_power_state_change_interrupt => open,
               cfg_msg_transmit_done            => open,
               cfg_msg_received                 => open,
               cfg_pl_status_change             => open,
               cfg_local_error_valid            => open,
               cfg_err_fatal_out                => open,
               cfg_err_nonfatal_out             => open,
               cfg_err_cor_out                  => open,
               cfg_mgmt_read_write_done         => open,
               cfg_phy_link_down                => open,
               pcie_rq_tag_vld1                 => open,
               pcie_rq_tag_vld0                 => open,
               pcie_rq_seq_num_vld1             => open,
               pcie_rq_seq_num_vld0             => open,
               m_axis_cq_tvalid                 => open,
               m_axis_cq_tlast                  => open,
               m_axis_rc_tvalid                 => open,
               m_axis_rc_tlast                  => open,
               user_lnk_up                      => open,
               user_reset                       => open,
               user_clk                         => open,
               -- cfg_interrupt_msi_fail                        => open,
               cfg_hot_reset_out                => open,
               phy_rdy_out                      => open
          );
end architecture;
