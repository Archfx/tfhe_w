----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: hbm_wrapper_hbm_1_left
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This makes one HBM stack with its 16 pseudo-channels accessible like BRAM. Note the following:
--                 Change the mode (read or write) as little as possible for maximum performance
--                 Disable global addressing in hbm ip core for this to work!
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

entity hbm_wrapper_hbm_1_left is
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
end entity;

architecture Behavioral of hbm_wrapper_hbm_1_left is

     component hbm_1 is
          port (
               HBM_REF_CLK_0       : in  std_logic;                                 -- 100 MHz, drives a PLL. Must be sourced from a MMCM/BUFG

               AXI_00_ACLK         : in  std_logic;                                 -- 450 MHz
               AXI_00_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
               -- start addr. must be 128-bit aligned, size must be multiple of 128bit
               AXI_00_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
               AXI_00_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst: use '01' # 00fixed(not supported), 01incr, 11wrap(like incr but wraps at the end, slower)
               AXI_00_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr. id tag (we have no need for this if the outputs are in the correct order, otherwise need ping-pong-buffer)
               AXI_00_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- read burst length --> constant '1111'
               AXI_00_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- read burst size, only 256-bit size supported (b'101')
               AXI_00_ARVALID      : in  std_logic;                                 -- read addr valid --> constant 1
               AXI_00_ARREADY      : out std_logic;                                 -- "read address ready" --> can accept a new read address
               -- same as for read
               AXI_00_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_00_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_00_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_00_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_00_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_00_AWVALID      : in  std_logic;
               AXI_00_AWREADY      : out std_logic;                                 -- "write address ready" --> can accept a new write address
               --
               AXI_00_RREADY       : in  std_logic;                                 --"read ready" signals that we read the input so the next one can come? Must be high to transmit the input data, set to 1
               AXI_00_BREADY       : in  std_logic;                                 --"response ready" --> read response, can accept new response
               AXI_00_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);            -- data to write
               AXI_00_WLAST        : in  std_logic;                                 -- shows that this was the last value that was written
               AXI_00_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);             -- write strobe --> one bit per write byte on the bus to tell that it should be written --> set all to 1.
               AXI_00_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);             -- why would I need that? Is data loss expeced?
               AXI_00_WVALID       : in  std_logic;
               AXI_00_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);             -- no need?
               AXI_00_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);            -- read data
               AXI_00_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_00_RLAST        : out std_logic;                                 -- shows that this was the last value that was read
               AXI_00_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);              -- read response --> which are possible?
               AXI_00_RVALID       : out std_logic;                                 -- signals output is there
               AXI_00_WREADY       : out std_logic;                                 -- signals that the values are now stored
               --
               AXI_00_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);              --"response ID tag" for AXI_00_BRESP
               AXI_00_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);              --Write response: 00 - OK, 01 - exclusive access OK, 10 - slave error, 11 decode error
               AXI_00_BVALID       : out std_logic;                                 --"Write response ready"

               AXI_01_ACLK         : in  std_logic;
               AXI_01_ARESET_N     : in  std_logic;
               AXI_01_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_01_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_01_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_01_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_01_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_01_ARVALID      : in  std_logic;
               AXI_01_ARREADY      : out std_logic;
               AXI_01_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_01_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_01_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_01_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_01_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_01_AWVALID      : in  std_logic;
               AXI_01_AWREADY      : out std_logic;
               AXI_01_RREADY       : in  std_logic;
               AXI_01_BREADY       : in  std_logic;
               AXI_01_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_01_WLAST        : in  std_logic;
               AXI_01_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_01_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_01_WVALID       : in  std_logic;
               AXI_01_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_01_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_01_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_01_RLAST        : out std_logic;
               AXI_01_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_01_RVALID       : out std_logic;
               AXI_01_WREADY       : out std_logic;
               AXI_01_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_01_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_01_BVALID       : out std_logic;

               AXI_02_ACLK         : in  std_logic;
               AXI_02_ARESET_N     : in  std_logic;
               AXI_02_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_02_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_02_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_02_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_02_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_02_ARVALID      : in  std_logic;
               AXI_02_ARREADY      : out std_logic;
               AXI_02_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_02_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_02_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_02_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_02_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_02_AWVALID      : in  std_logic;
               AXI_02_AWREADY      : out std_logic;
               AXI_02_RREADY       : in  std_logic;
               AXI_02_BREADY       : in  std_logic;
               AXI_02_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_02_WLAST        : in  std_logic;
               AXI_02_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_02_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_02_WVALID       : in  std_logic;
               AXI_02_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_02_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_02_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_02_RLAST        : out std_logic;
               AXI_02_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_02_RVALID       : out std_logic;
               AXI_02_WREADY       : out std_logic;
               AXI_02_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_02_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_02_BVALID       : out std_logic;

               AXI_03_ACLK         : in  std_logic;
               AXI_03_ARESET_N     : in  std_logic;
               AXI_03_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_03_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_03_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_03_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_03_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_03_ARVALID      : in  std_logic;
               AXI_03_ARREADY      : out std_logic;
               AXI_03_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_03_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_03_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_03_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_03_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_03_AWVALID      : in  std_logic;
               AXI_03_AWREADY      : out std_logic;
               AXI_03_RREADY       : in  std_logic;
               AXI_03_BREADY       : in  std_logic;
               AXI_03_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_03_WLAST        : in  std_logic;
               AXI_03_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_03_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_03_WVALID       : in  std_logic;
               AXI_03_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_03_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_03_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_03_RLAST        : out std_logic;
               AXI_03_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_03_RVALID       : out std_logic;
               AXI_03_WREADY       : out std_logic;
               AXI_03_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_03_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_03_BVALID       : out std_logic;

               AXI_04_ACLK         : in  std_logic;
               AXI_04_ARESET_N     : in  std_logic;
               AXI_04_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_04_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_04_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_04_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_04_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_04_ARVALID      : in  std_logic;
               AXI_04_ARREADY      : out std_logic;
               AXI_04_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_04_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_04_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_04_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_04_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_04_AWVALID      : in  std_logic;
               AXI_04_AWREADY      : out std_logic;
               AXI_04_RREADY       : in  std_logic;
               AXI_04_BREADY       : in  std_logic;
               AXI_04_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_04_WLAST        : in  std_logic;
               AXI_04_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_04_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_04_WVALID       : in  std_logic;
               AXI_04_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_04_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_04_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_04_RLAST        : out std_logic;
               AXI_04_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_04_RVALID       : out std_logic;
               AXI_04_WREADY       : out std_logic;
               AXI_04_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_04_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_04_BVALID       : out std_logic;

               AXI_05_ACLK         : in  std_logic;
               AXI_05_ARESET_N     : in  std_logic;
               AXI_05_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_05_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_05_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_05_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_05_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_05_ARVALID      : in  std_logic;
               AXI_05_ARREADY      : out std_logic;
               AXI_05_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_05_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_05_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_05_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_05_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_05_AWVALID      : in  std_logic;
               AXI_05_AWREADY      : out std_logic;
               AXI_05_RREADY       : in  std_logic;
               AXI_05_BREADY       : in  std_logic;
               AXI_05_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_05_WLAST        : in  std_logic;
               AXI_05_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_05_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_05_WVALID       : in  std_logic;
               AXI_05_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_05_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_05_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_05_RLAST        : out std_logic;
               AXI_05_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_05_RVALID       : out std_logic;
               AXI_05_WREADY       : out std_logic;
               AXI_05_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_05_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_05_BVALID       : out std_logic;

               AXI_06_ACLK         : in  std_logic;
               AXI_06_ARESET_N     : in  std_logic;
               AXI_06_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_06_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_06_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_06_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_06_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_06_ARVALID      : in  std_logic;
               AXI_06_ARREADY      : out std_logic;
               AXI_06_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_06_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_06_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_06_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_06_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_06_AWVALID      : in  std_logic;
               AXI_06_AWREADY      : out std_logic;
               AXI_06_RREADY       : in  std_logic;
               AXI_06_BREADY       : in  std_logic;
               AXI_06_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_06_WLAST        : in  std_logic;
               AXI_06_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_06_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_06_WVALID       : in  std_logic;
               AXI_06_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_06_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_06_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_06_RLAST        : out std_logic;
               AXI_06_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_06_RVALID       : out std_logic;
               AXI_06_WREADY       : out std_logic;
               AXI_06_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_06_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_06_BVALID       : out std_logic;

               AXI_07_ACLK         : in  std_logic;
               AXI_07_ARESET_N     : in  std_logic;
               AXI_07_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_07_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_07_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_07_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_07_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_07_ARVALID      : in  std_logic;
               AXI_07_ARREADY      : out std_logic;
               AXI_07_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_07_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_07_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_07_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_07_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_07_AWVALID      : in  std_logic;
               AXI_07_AWREADY      : out std_logic;
               AXI_07_RREADY       : in  std_logic;
               AXI_07_BREADY       : in  std_logic;
               AXI_07_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_07_WLAST        : in  std_logic;
               AXI_07_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_07_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_07_WVALID       : in  std_logic;
               AXI_07_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_07_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_07_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_07_RLAST        : out std_logic;
               AXI_07_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_07_RVALID       : out std_logic;
               AXI_07_WREADY       : out std_logic;
               AXI_07_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_07_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_07_BVALID       : out std_logic;

               AXI_08_ACLK         : in  std_logic;
               AXI_08_ARESET_N     : in  std_logic;
               AXI_08_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_08_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_08_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_08_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_08_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_08_ARVALID      : in  std_logic;
               AXI_08_ARREADY      : out std_logic;
               AXI_08_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_08_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_08_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_08_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_08_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_08_AWVALID      : in  std_logic;
               AXI_08_AWREADY      : out std_logic;
               AXI_08_RREADY       : in  std_logic;
               AXI_08_BREADY       : in  std_logic;
               AXI_08_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_08_WLAST        : in  std_logic;
               AXI_08_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_08_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_08_WVALID       : in  std_logic;
               AXI_08_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_08_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_08_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_08_RLAST        : out std_logic;
               AXI_08_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_08_RVALID       : out std_logic;
               AXI_08_WREADY       : out std_logic;
               AXI_08_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_08_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_08_BVALID       : out std_logic;

               AXI_09_ACLK         : in  std_logic;
               AXI_09_ARESET_N     : in  std_logic;
               AXI_09_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_09_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_09_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_09_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_09_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_09_ARVALID      : in  std_logic;
               AXI_09_ARREADY      : out std_logic;
               AXI_09_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_09_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_09_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_09_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_09_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_09_AWVALID      : in  std_logic;
               AXI_09_AWREADY      : out std_logic;
               AXI_09_RREADY       : in  std_logic;
               AXI_09_BREADY       : in  std_logic;
               AXI_09_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_09_WLAST        : in  std_logic;
               AXI_09_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_09_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_09_WVALID       : in  std_logic;
               AXI_09_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_09_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_09_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_09_RLAST        : out std_logic;
               AXI_09_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_09_RVALID       : out std_logic;
               AXI_09_WREADY       : out std_logic;
               AXI_09_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_09_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_09_BVALID       : out std_logic;

               AXI_10_ACLK         : in  std_logic;
               AXI_10_ARESET_N     : in  std_logic;
               AXI_10_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_10_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_10_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_10_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_10_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_10_ARVALID      : in  std_logic;
               AXI_10_ARREADY      : out std_logic;
               AXI_10_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_10_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_10_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_10_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_10_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_10_AWVALID      : in  std_logic;
               AXI_10_AWREADY      : out std_logic;
               AXI_10_RREADY       : in  std_logic;
               AXI_10_BREADY       : in  std_logic;
               AXI_10_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_10_WLAST        : in  std_logic;
               AXI_10_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_10_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_10_WVALID       : in  std_logic;
               AXI_10_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_10_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_10_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_10_RLAST        : out std_logic;
               AXI_10_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_10_RVALID       : out std_logic;
               AXI_10_WREADY       : out std_logic;
               AXI_10_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_10_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_10_BVALID       : out std_logic;

               AXI_11_ACLK         : in  std_logic;
               AXI_11_ARESET_N     : in  std_logic;
               AXI_11_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_11_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_11_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_11_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_11_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_11_ARVALID      : in  std_logic;
               AXI_11_ARREADY      : out std_logic;
               AXI_11_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_11_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_11_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_11_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_11_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_11_AWVALID      : in  std_logic;
               AXI_11_AWREADY      : out std_logic;
               AXI_11_RREADY       : in  std_logic;
               AXI_11_BREADY       : in  std_logic;
               AXI_11_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_11_WLAST        : in  std_logic;
               AXI_11_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_11_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_11_WVALID       : in  std_logic;
               AXI_11_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_11_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_11_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_11_RLAST        : out std_logic;
               AXI_11_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_11_RVALID       : out std_logic;
               AXI_11_WREADY       : out std_logic;
               AXI_11_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_11_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_11_BVALID       : out std_logic;

               AXI_12_ACLK         : in  std_logic;
               AXI_12_ARESET_N     : in  std_logic;
               AXI_12_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_12_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_12_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_12_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_12_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_12_ARVALID      : in  std_logic;
               AXI_12_ARREADY      : out std_logic;
               AXI_12_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_12_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_12_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_12_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_12_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_12_AWVALID      : in  std_logic;
               AXI_12_AWREADY      : out std_logic;
               AXI_12_RREADY       : in  std_logic;
               AXI_12_BREADY       : in  std_logic;
               AXI_12_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_12_WLAST        : in  std_logic;
               AXI_12_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_12_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_12_WVALID       : in  std_logic;
               AXI_12_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_12_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_12_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_12_RLAST        : out std_logic;
               AXI_12_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_12_RVALID       : out std_logic;
               AXI_12_WREADY       : out std_logic;
               AXI_12_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_12_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_12_BVALID       : out std_logic;

               AXI_13_ACLK         : in  std_logic;
               AXI_13_ARESET_N     : in  std_logic;
               AXI_13_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_13_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_13_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_13_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_13_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_13_ARVALID      : in  std_logic;
               AXI_13_ARREADY      : out std_logic;
               AXI_13_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_13_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_13_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_13_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_13_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_13_AWVALID      : in  std_logic;
               AXI_13_AWREADY      : out std_logic;
               AXI_13_RREADY       : in  std_logic;
               AXI_13_BREADY       : in  std_logic;
               AXI_13_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_13_WLAST        : in  std_logic;
               AXI_13_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_13_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_13_WVALID       : in  std_logic;
               AXI_13_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_13_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_13_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_13_RLAST        : out std_logic;
               AXI_13_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_13_RVALID       : out std_logic;
               AXI_13_WREADY       : out std_logic;
               AXI_13_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_13_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_13_BVALID       : out std_logic;

               AXI_14_ACLK         : in  std_logic;
               AXI_14_ARESET_N     : in  std_logic;
               AXI_14_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_14_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_14_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_14_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_14_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_14_ARVALID      : in  std_logic;
               AXI_14_ARREADY      : out std_logic;
               AXI_14_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_14_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_14_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_14_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_14_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_14_AWVALID      : in  std_logic;
               AXI_14_AWREADY      : out std_logic;
               AXI_14_RREADY       : in  std_logic;
               AXI_14_BREADY       : in  std_logic;
               AXI_14_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_14_WLAST        : in  std_logic;
               AXI_14_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_14_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_14_WVALID       : in  std_logic;
               AXI_14_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_14_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_14_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_14_RLAST        : out std_logic;
               AXI_14_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_14_RVALID       : out std_logic;
               AXI_14_WREADY       : out std_logic;
               AXI_14_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_14_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_14_BVALID       : out std_logic;

               AXI_15_ACLK         : in  std_logic;
               AXI_15_ARESET_N     : in  std_logic;
               AXI_15_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_15_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_15_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_15_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_15_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_15_ARVALID      : in  std_logic;
               AXI_15_ARREADY      : out std_logic;
               AXI_15_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
               AXI_15_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
               AXI_15_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_15_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
               AXI_15_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
               AXI_15_AWVALID      : in  std_logic;
               AXI_15_AWREADY      : out std_logic;
               AXI_15_RREADY       : in  std_logic;
               AXI_15_BREADY       : in  std_logic;
               AXI_15_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
               AXI_15_WLAST        : in  std_logic;
               AXI_15_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_15_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_15_WVALID       : in  std_logic;
               AXI_15_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               AXI_15_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
               AXI_15_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_15_RLAST        : out std_logic;
               AXI_15_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_15_RVALID       : out std_logic;
               AXI_15_WREADY       : out std_logic;
               AXI_15_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
               AXI_15_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
               AXI_15_BVALID       : out std_logic;

               -- repeat till AXI_15

               -- APB configures the HBM during startup
               APB_0_PCLK          : in  std_logic;                                 -- "APB port clock", must match with apb interface clock which is between 50 MHz and 100 MHz
               APB_0_PRESET_N      : in  std_logic;

               -- APB_0_PWDATA        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               -- APB_0_PADDR         : in  std_logic_vector(21 downto 0);
               -- APB_0_PENABLE       : in  std_logic;
               -- APB_0_PSEL          : in  std_logic;
               -- APB_0_PWRITE        : in  std_logic;
               -- APB_0_PRDATA        : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
               -- APB_0_PREADY        : out std_logic;
               -- APB_0_PSLVERR       : out std_logic;
               apb_complete_0      : out std_logic;                                 -- indicates that the initial configuration is complete
               DRAM_0_STAT_CATTRIP : out std_logic;                                 -- catastrophiccally high temperatures, shutdown memory access!
               DRAM_0_STAT_TEMP    : out std_logic_vector(6 downto 0)
          );
     end component;

begin

     hbm_1_inst: hbm_1
          port map (
               HBM_REF_CLK_0       => i_clk_ref,
               -- AXI in short: the party that sends the data sets valid='1', the party that receives the data indicates that through ready='1'
               -- here we transmit read/write-address and the write-data and we receive the read-data
               AXI_00_ACLK         => i_clk,
               AXI_00_ARESET_N     => i_reset_n,
               AXI_00_ARADDR       => std_logic_vector(i_read_pkgs(0).araddr),
               AXI_00_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_00_ARID         => i_read_pkgs(0).arid,
               AXI_00_ARLEN        => i_read_pkgs(0).arlen,
               AXI_00_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_00_ARVALID      => i_read_pkgs(0).arvalid,
               AXI_00_ARREADY      => o_read_pkgs(0).arready,
               AXI_00_AWADDR       => std_logic_vector(i_write_pkgs(0).awaddr),
               AXI_00_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_00_AWID         => i_write_pkgs(0).awid,
               AXI_00_AWLEN        => i_write_pkgs(0).awlen,
               AXI_00_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_00_AWVALID      => i_write_pkgs(0).awvalid,
               AXI_00_AWREADY      => o_write_pkgs(0).awready,
               AXI_00_RREADY       => i_read_pkgs(0).rready,
               AXI_00_BREADY       => i_write_pkgs(0).bready,
               AXI_00_WDATA        => i_write_pkgs(0).wdata,
               AXI_00_WLAST        => i_write_pkgs(0).wlast,
               AXI_00_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_00_WDATA_PARITY => i_write_pkgs(0).wdata_parity,
               AXI_00_WVALID       => i_write_pkgs(0).wvalid,
               AXI_00_RDATA_PARITY => o_read_pkgs(0).rdata_parity,
               AXI_00_RDATA        => o_read_pkgs(0).rdata,
               AXI_00_RID          => o_read_pkgs(0).rid,
               AXI_00_RLAST        => o_read_pkgs(0).rlast,
               AXI_00_RRESP        => o_read_pkgs(0).rresp,
               AXI_00_RVALID       => o_read_pkgs(0).rvalid,
               AXI_00_WREADY       => o_write_pkgs(0).wready,
               AXI_00_BID          => o_write_pkgs(0).bid,
               AXI_00_BRESP        => o_write_pkgs(0).bresp,
               AXI_00_BVALID       => o_write_pkgs(0).bvalid,

               -- the outputs response_id, read_last, read_valid and write_ready should be the same for all banks, so we dont set them
               AXI_01_ACLK         => i_clk,
               AXI_01_ARESET_N     => i_reset_n,
               AXI_01_ARADDR       => std_logic_vector(i_read_pkgs(1).araddr),
               AXI_01_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_01_ARID         => i_read_pkgs(1).arid,
               AXI_01_ARLEN        => i_read_pkgs(1).arlen,
               AXI_01_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_01_ARVALID      => i_read_pkgs(1).arvalid,
               AXI_01_ARREADY      => o_read_pkgs(1).arready,
               AXI_01_AWADDR       => std_logic_vector(i_write_pkgs(1).awaddr),
               AXI_01_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_01_AWID         => i_write_pkgs(1).awid,
               AXI_01_AWLEN        => i_write_pkgs(1).awlen,
               AXI_01_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_01_AWVALID      => i_write_pkgs(1).awvalid,
               AXI_01_AWREADY      => o_write_pkgs(1).awready,
               AXI_01_RREADY       => i_read_pkgs(1).rready,
               AXI_01_BREADY       => i_write_pkgs(1).bready,
               AXI_01_WDATA        => i_write_pkgs(1).wdata,
               AXI_01_WLAST        => i_write_pkgs(1).wlast,
               AXI_01_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_01_WDATA_PARITY => i_write_pkgs(1).wdata_parity,
               AXI_01_WVALID       => i_write_pkgs(1).wvalid,
               AXI_01_RDATA_PARITY => o_read_pkgs(1).rdata_parity,
               AXI_01_RDATA        => o_read_pkgs(1).rdata,
               AXI_01_RID          => o_read_pkgs(1).rid,
               AXI_01_RLAST        => o_read_pkgs(1).rlast,
               AXI_01_RRESP        => o_read_pkgs(1).rresp,
               AXI_01_RVALID       => o_read_pkgs(1).rvalid,
               AXI_01_WREADY       => o_write_pkgs(1).wready,
               AXI_01_BID          => o_write_pkgs(1).bid,
               AXI_01_BRESP        => o_write_pkgs(1).bresp,
               AXI_01_BVALID       => o_write_pkgs(1).bvalid,

               AXI_02_ACLK         => i_clk,
               AXI_02_ARESET_N     => i_reset_n,
               AXI_02_ARADDR       => std_logic_vector(i_read_pkgs(2).araddr),
               AXI_02_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_02_ARID         => i_read_pkgs(2).arid,
               AXI_02_ARLEN        => i_read_pkgs(2).arlen,
               AXI_02_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_02_ARVALID      => i_read_pkgs(2).arvalid,
               AXI_02_ARREADY      => o_read_pkgs(2).arready,
               AXI_02_AWADDR       => std_logic_vector(i_write_pkgs(2).awaddr),
               AXI_02_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_02_AWID         => i_write_pkgs(2).awid,
               AXI_02_AWLEN        => i_write_pkgs(2).awlen,
               AXI_02_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_02_AWVALID      => i_write_pkgs(2).awvalid,
               AXI_02_AWREADY      => o_write_pkgs(2).awready,
               AXI_02_RREADY       => i_read_pkgs(2).rready,
               AXI_02_BREADY       => i_write_pkgs(2).bready,
               AXI_02_WDATA        => i_write_pkgs(2).wdata,
               AXI_02_WLAST        => i_write_pkgs(2).wlast,
               AXI_02_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_02_WDATA_PARITY => i_write_pkgs(2).wdata_parity,
               AXI_02_WVALID       => i_write_pkgs(2).wvalid,
               AXI_02_RDATA_PARITY => o_read_pkgs(2).rdata_parity,
               AXI_02_RDATA        => o_read_pkgs(2).rdata,
               AXI_02_RID          => o_read_pkgs(2).rid,
               AXI_02_RLAST        => o_read_pkgs(2).rlast,
               AXI_02_RRESP        => o_read_pkgs(2).rresp,
               AXI_02_RVALID       => o_read_pkgs(2).rvalid,
               AXI_02_WREADY       => o_write_pkgs(2).wready,
               AXI_02_BID          => o_write_pkgs(2).bid,
               AXI_02_BRESP        => o_write_pkgs(2).bresp,
               AXI_02_BVALID       => o_write_pkgs(2).bvalid,

               AXI_03_ACLK         => i_clk,
               AXI_03_ARESET_N     => i_reset_n,
               AXI_03_ARADDR       => std_logic_vector(i_read_pkgs(3).araddr),
               AXI_03_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_03_ARID         => i_read_pkgs(3).arid,
               AXI_03_ARLEN        => i_read_pkgs(3).arlen,
               AXI_03_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_03_ARVALID      => i_read_pkgs(3).arvalid,
               AXI_03_ARREADY      => o_read_pkgs(3).arready,
               AXI_03_AWADDR       => std_logic_vector(i_write_pkgs(3).awaddr),
               AXI_03_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_03_AWID         => i_write_pkgs(3).awid,
               AXI_03_AWLEN        => i_write_pkgs(3).awlen,
               AXI_03_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_03_AWVALID      => i_write_pkgs(3).awvalid,
               AXI_03_AWREADY      => o_write_pkgs(3).awready,
               AXI_03_RREADY       => i_read_pkgs(3).rready,
               AXI_03_BREADY       => i_write_pkgs(3).bready,
               AXI_03_WDATA        => i_write_pkgs(3).wdata,
               AXI_03_WLAST        => i_write_pkgs(3).wlast,
               AXI_03_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_03_WDATA_PARITY => i_write_pkgs(3).wdata_parity,
               AXI_03_WVALID       => i_write_pkgs(3).wvalid,
               AXI_03_RDATA_PARITY => o_read_pkgs(3).rdata_parity,
               AXI_03_RDATA        => o_read_pkgs(3).rdata,
               AXI_03_RID          => o_read_pkgs(3).rid,
               AXI_03_RLAST        => o_read_pkgs(3).rlast,
               AXI_03_RRESP        => o_read_pkgs(3).rresp,
               AXI_03_RVALID       => o_read_pkgs(3).rvalid,
               AXI_03_WREADY       => o_write_pkgs(3).wready,
               AXI_03_BID          => o_write_pkgs(3).bid,
               AXI_03_BRESP        => o_write_pkgs(3).bresp,
               AXI_03_BVALID       => o_write_pkgs(3).bvalid,

               AXI_04_ACLK         => i_clk,
               AXI_04_ARESET_N     => i_reset_n,
               AXI_04_ARADDR       => std_logic_vector(i_read_pkgs(4).araddr),
               AXI_04_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_04_ARID         => i_read_pkgs(4).arid,
               AXI_04_ARLEN        => i_read_pkgs(4).arlen,
               AXI_04_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_04_ARVALID      => i_read_pkgs(4).arvalid,
               AXI_04_ARREADY      => o_read_pkgs(4).arready,
               AXI_04_AWADDR       => std_logic_vector(i_write_pkgs(4).awaddr),
               AXI_04_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_04_AWID         => i_write_pkgs(4).awid,
               AXI_04_AWLEN        => i_write_pkgs(4).awlen,
               AXI_04_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_04_AWVALID      => i_write_pkgs(4).awvalid,
               AXI_04_AWREADY      => o_write_pkgs(4).awready,
               AXI_04_RREADY       => i_read_pkgs(4).rready,
               AXI_04_BREADY       => i_write_pkgs(4).bready,
               AXI_04_WDATA        => i_write_pkgs(4).wdata,
               AXI_04_WLAST        => i_write_pkgs(4).wlast,
               AXI_04_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_04_WDATA_PARITY => i_write_pkgs(4).wdata_parity,
               AXI_04_WVALID       => i_write_pkgs(4).wvalid,
               AXI_04_RDATA_PARITY => o_read_pkgs(4).rdata_parity,
               AXI_04_RDATA        => o_read_pkgs(4).rdata,
               AXI_04_RID          => o_read_pkgs(4).rid,
               AXI_04_RLAST        => o_read_pkgs(4).rlast,
               AXI_04_RRESP        => o_read_pkgs(4).rresp,
               AXI_04_RVALID       => o_read_pkgs(4).rvalid,
               AXI_04_WREADY       => o_write_pkgs(4).wready,
               AXI_04_BID          => o_write_pkgs(4).bid,
               AXI_04_BRESP        => o_write_pkgs(4).bresp,
               AXI_04_BVALID       => o_write_pkgs(4).bvalid,

               AXI_05_ACLK         => i_clk,
               AXI_05_ARESET_N     => i_reset_n,
               AXI_05_ARADDR       => std_logic_vector(i_read_pkgs(5).araddr),
               AXI_05_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_05_ARID         => i_read_pkgs(5).arid,
               AXI_05_ARLEN        => i_read_pkgs(5).arlen,
               AXI_05_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_05_ARVALID      => i_read_pkgs(5).arvalid,
               AXI_05_ARREADY      => o_read_pkgs(5).arready,
               AXI_05_AWADDR       => std_logic_vector(i_write_pkgs(5).awaddr),
               AXI_05_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_05_AWID         => i_write_pkgs(5).awid,
               AXI_05_AWLEN        => i_write_pkgs(5).awlen,
               AXI_05_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_05_AWVALID      => i_write_pkgs(5).awvalid,
               AXI_05_AWREADY      => o_write_pkgs(5).awready,
               AXI_05_RREADY       => i_read_pkgs(5).rready,
               AXI_05_BREADY       => i_write_pkgs(5).bready,
               AXI_05_WDATA        => i_write_pkgs(5).wdata,
               AXI_05_WLAST        => i_write_pkgs(5).wlast,
               AXI_05_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_05_WDATA_PARITY => i_write_pkgs(5).wdata_parity,
               AXI_05_WVALID       => i_write_pkgs(5).wvalid,
               AXI_05_RDATA_PARITY => o_read_pkgs(5).rdata_parity,
               AXI_05_RDATA        => o_read_pkgs(5).rdata,
               AXI_05_RID          => o_read_pkgs(5).rid,
               AXI_05_RLAST        => o_read_pkgs(5).rlast,
               AXI_05_RRESP        => o_read_pkgs(5).rresp,
               AXI_05_RVALID       => o_read_pkgs(5).rvalid,
               AXI_05_WREADY       => o_write_pkgs(5).wready,
               AXI_05_BID          => o_write_pkgs(5).bid,
               AXI_05_BRESP        => o_write_pkgs(5).bresp,
               AXI_05_BVALID       => o_write_pkgs(5).bvalid,

               AXI_06_ACLK         => i_clk,
               AXI_06_ARESET_N     => i_reset_n,
               AXI_06_ARADDR       => std_logic_vector(i_read_pkgs(6).araddr),
               AXI_06_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_06_ARID         => i_read_pkgs(6).arid,
               AXI_06_ARLEN        => i_read_pkgs(6).arlen,
               AXI_06_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_06_ARVALID      => i_read_pkgs(6).arvalid,
               AXI_06_ARREADY      => o_read_pkgs(6).arready,
               AXI_06_AWADDR       => std_logic_vector(i_write_pkgs(6).awaddr),
               AXI_06_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_06_AWID         => i_write_pkgs(6).awid,
               AXI_06_AWLEN        => i_write_pkgs(6).awlen,
               AXI_06_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_06_AWVALID      => i_write_pkgs(6).awvalid,
               AXI_06_AWREADY      => o_write_pkgs(6).awready,
               AXI_06_RREADY       => i_read_pkgs(6).rready,
               AXI_06_BREADY       => i_write_pkgs(6).bready,
               AXI_06_WDATA        => i_write_pkgs(6).wdata,
               AXI_06_WLAST        => i_write_pkgs(6).wlast,
               AXI_06_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_06_WDATA_PARITY => i_write_pkgs(6).wdata_parity,
               AXI_06_WVALID       => i_write_pkgs(6).wvalid,
               AXI_06_RDATA_PARITY => o_read_pkgs(6).rdata_parity,
               AXI_06_RDATA        => o_read_pkgs(6).rdata,
               AXI_06_RID          => o_read_pkgs(6).rid,
               AXI_06_RLAST        => o_read_pkgs(6).rlast,
               AXI_06_RRESP        => o_read_pkgs(6).rresp,
               AXI_06_RVALID       => o_read_pkgs(6).rvalid,
               AXI_06_WREADY       => o_write_pkgs(6).wready,
               AXI_06_BID          => o_write_pkgs(6).bid,
               AXI_06_BRESP        => o_write_pkgs(6).bresp,
               AXI_06_BVALID       => o_write_pkgs(6).bvalid,

               AXI_07_ACLK         => i_clk,
               AXI_07_ARESET_N     => i_reset_n,
               AXI_07_ARADDR       => std_logic_vector(i_read_pkgs(7).araddr),
               AXI_07_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_07_ARID         => i_read_pkgs(7).arid,
               AXI_07_ARLEN        => i_read_pkgs(7).arlen,
               AXI_07_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_07_ARVALID      => i_read_pkgs(7).arvalid,
               AXI_07_ARREADY      => o_read_pkgs(7).arready,
               AXI_07_AWADDR       => std_logic_vector(i_write_pkgs(7).awaddr),
               AXI_07_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_07_AWID         => i_write_pkgs(7).awid,
               AXI_07_AWLEN        => i_write_pkgs(7).awlen,
               AXI_07_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_07_AWVALID      => i_write_pkgs(7).awvalid,
               AXI_07_AWREADY      => o_write_pkgs(7).awready,
               AXI_07_RREADY       => i_read_pkgs(7).rready,
               AXI_07_BREADY       => i_write_pkgs(7).bready,
               AXI_07_WDATA        => i_write_pkgs(7).wdata,
               AXI_07_WLAST        => i_write_pkgs(7).wlast,
               AXI_07_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_07_WDATA_PARITY => i_write_pkgs(7).wdata_parity,
               AXI_07_WVALID       => i_write_pkgs(7).wvalid,
               AXI_07_RDATA_PARITY => o_read_pkgs(7).rdata_parity,
               AXI_07_RDATA        => o_read_pkgs(7).rdata,
               AXI_07_RID          => o_read_pkgs(7).rid,
               AXI_07_RLAST        => o_read_pkgs(7).rlast,
               AXI_07_RRESP        => o_read_pkgs(7).rresp,
               AXI_07_RVALID       => o_read_pkgs(7).rvalid,
               AXI_07_WREADY       => o_write_pkgs(7).wready,
               AXI_07_BID          => o_write_pkgs(7).bid,
               AXI_07_BRESP        => o_write_pkgs(7).bresp,
               AXI_07_BVALID       => o_write_pkgs(7).bvalid,

               AXI_08_ACLK         => i_clk,
               AXI_08_ARESET_N     => i_reset_n,
               AXI_08_ARADDR       => std_logic_vector(i_read_pkgs(8).araddr),
               AXI_08_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_08_ARID         => i_read_pkgs(8).arid,
               AXI_08_ARLEN        => i_read_pkgs(8).arlen,
               AXI_08_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_08_ARVALID      => i_read_pkgs(8).arvalid,
               AXI_08_ARREADY      => o_read_pkgs(8).arready,
               AXI_08_AWADDR       => std_logic_vector(i_write_pkgs(8).awaddr),
               AXI_08_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_08_AWID         => i_write_pkgs(8).awid,
               AXI_08_AWLEN        => i_write_pkgs(8).awlen,
               AXI_08_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_08_AWVALID      => i_write_pkgs(8).awvalid,
               AXI_08_AWREADY      => o_write_pkgs(8).awready,
               AXI_08_RREADY       => i_read_pkgs(8).rready,
               AXI_08_BREADY       => i_write_pkgs(8).bready,
               AXI_08_WDATA        => i_write_pkgs(8).wdata,
               AXI_08_WLAST        => i_write_pkgs(8).wlast,
               AXI_08_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_08_WDATA_PARITY => i_write_pkgs(8).wdata_parity,
               AXI_08_WVALID       => i_write_pkgs(8).wvalid,
               AXI_08_RDATA_PARITY => o_read_pkgs(8).rdata_parity,
               AXI_08_RDATA        => o_read_pkgs(8).rdata,
               AXI_08_RID          => o_read_pkgs(8).rid,
               AXI_08_RLAST        => o_read_pkgs(8).rlast,
               AXI_08_RRESP        => o_read_pkgs(8).rresp,
               AXI_08_RVALID       => o_read_pkgs(8).rvalid,
               AXI_08_WREADY       => o_write_pkgs(8).wready,
               AXI_08_BID          => o_write_pkgs(8).bid,
               AXI_08_BRESP        => o_write_pkgs(8).bresp,
               AXI_08_BVALID       => o_write_pkgs(8).bvalid,

               AXI_09_ACLK         => i_clk,
               AXI_09_ARESET_N     => i_reset_n,
               AXI_09_ARADDR       => std_logic_vector(i_read_pkgs(9).araddr),
               AXI_09_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_09_ARID         => i_read_pkgs(9).arid,
               AXI_09_ARLEN        => i_read_pkgs(9).arlen,
               AXI_09_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_09_ARVALID      => i_read_pkgs(9).arvalid,
               AXI_09_ARREADY      => o_read_pkgs(9).arready,
               AXI_09_AWADDR       => std_logic_vector(i_write_pkgs(9).awaddr),
               AXI_09_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_09_AWID         => i_write_pkgs(9).awid,
               AXI_09_AWLEN        => i_write_pkgs(9).awlen,
               AXI_09_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_09_AWVALID      => i_write_pkgs(9).awvalid,
               AXI_09_AWREADY      => o_write_pkgs(9).awready,
               AXI_09_RREADY       => i_read_pkgs(9).rready,
               AXI_09_BREADY       => i_write_pkgs(9).bready,
               AXI_09_WDATA        => i_write_pkgs(9).wdata,
               AXI_09_WLAST        => i_write_pkgs(9).wlast,
               AXI_09_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_09_WDATA_PARITY => i_write_pkgs(9).wdata_parity,
               AXI_09_WVALID       => i_write_pkgs(9).wvalid,
               AXI_09_RDATA_PARITY => o_read_pkgs(9).rdata_parity,
               AXI_09_RDATA        => o_read_pkgs(9).rdata,
               AXI_09_RID          => o_read_pkgs(9).rid,
               AXI_09_RLAST        => o_read_pkgs(9).rlast,
               AXI_09_RRESP        => o_read_pkgs(9).rresp,
               AXI_09_RVALID       => o_read_pkgs(9).rvalid,
               AXI_09_WREADY       => o_write_pkgs(9).wready,
               AXI_09_BID          => o_write_pkgs(9).bid,
               AXI_09_BRESP        => o_write_pkgs(9).bresp,
               AXI_09_BVALID       => o_write_pkgs(9).bvalid,

               AXI_10_ACLK         => i_clk,
               AXI_10_ARESET_N     => i_reset_n,
               AXI_10_ARADDR       => std_logic_vector(i_read_pkgs(10).araddr),
               AXI_10_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_10_ARID         => i_read_pkgs(10).arid,
               AXI_10_ARLEN        => i_read_pkgs(10).arlen,
               AXI_10_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_10_ARVALID      => i_read_pkgs(10).arvalid,
               AXI_10_ARREADY      => o_read_pkgs(10).arready,
               AXI_10_AWADDR       => std_logic_vector(i_write_pkgs(10).awaddr),
               AXI_10_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_10_AWID         => i_write_pkgs(10).awid,
               AXI_10_AWLEN        => i_write_pkgs(10).awlen,
               AXI_10_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_10_AWVALID      => i_write_pkgs(10).awvalid,
               AXI_10_AWREADY      => o_write_pkgs(10).awready,
               AXI_10_RREADY       => i_read_pkgs(10).rready,
               AXI_10_BREADY       => i_write_pkgs(10).bready,
               AXI_10_WDATA        => i_write_pkgs(10).wdata,
               AXI_10_WLAST        => i_write_pkgs(10).wlast,
               AXI_10_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_10_WDATA_PARITY => i_write_pkgs(10).wdata_parity,
               AXI_10_WVALID       => i_write_pkgs(10).wvalid,
               AXI_10_RDATA_PARITY => o_read_pkgs(10).rdata_parity,
               AXI_10_RDATA        => o_read_pkgs(10).rdata,
               AXI_10_RID          => o_read_pkgs(10).rid,
               AXI_10_RLAST        => o_read_pkgs(10).rlast,
               AXI_10_RRESP        => o_read_pkgs(10).rresp,
               AXI_10_RVALID       => o_read_pkgs(10).rvalid,
               AXI_10_WREADY       => o_write_pkgs(10).wready,
               AXI_10_BID          => o_write_pkgs(10).bid,
               AXI_10_BRESP        => o_write_pkgs(10).bresp,
               AXI_10_BVALID       => o_write_pkgs(10).bvalid,

               AXI_11_ACLK         => i_clk,
               AXI_11_ARESET_N     => i_reset_n,
               AXI_11_ARADDR       => std_logic_vector(i_read_pkgs(11).araddr),
               AXI_11_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_11_ARID         => i_read_pkgs(11).arid,
               AXI_11_ARLEN        => i_read_pkgs(11).arlen,
               AXI_11_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_11_ARVALID      => i_read_pkgs(11).arvalid,
               AXI_11_ARREADY      => o_read_pkgs(11).arready,
               AXI_11_AWADDR       => std_logic_vector(i_write_pkgs(11).awaddr),
               AXI_11_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_11_AWID         => i_write_pkgs(11).awid,
               AXI_11_AWLEN        => i_write_pkgs(11).awlen,
               AXI_11_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_11_AWVALID      => i_write_pkgs(11).awvalid,
               AXI_11_AWREADY      => o_write_pkgs(11).awready,
               AXI_11_RREADY       => i_read_pkgs(11).rready,
               AXI_11_BREADY       => i_write_pkgs(11).bready,
               AXI_11_WDATA        => i_write_pkgs(11).wdata,
               AXI_11_WLAST        => i_write_pkgs(11).wlast,
               AXI_11_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_11_WDATA_PARITY => i_write_pkgs(11).wdata_parity,
               AXI_11_WVALID       => i_write_pkgs(11).wvalid,
               AXI_11_RDATA_PARITY => o_read_pkgs(11).rdata_parity,
               AXI_11_RDATA        => o_read_pkgs(11).rdata,
               AXI_11_RID          => o_read_pkgs(11).rid,
               AXI_11_RLAST        => o_read_pkgs(11).rlast,
               AXI_11_RRESP        => o_read_pkgs(11).rresp,
               AXI_11_RVALID       => o_read_pkgs(11).rvalid,
               AXI_11_WREADY       => o_write_pkgs(11).wready,
               AXI_11_BID          => o_write_pkgs(11).bid,
               AXI_11_BRESP        => o_write_pkgs(11).bresp,
               AXI_11_BVALID       => o_write_pkgs(11).bvalid,

               AXI_12_ACLK         => i_clk,
               AXI_12_ARESET_N     => i_reset_n,
               AXI_12_ARADDR       => std_logic_vector(i_read_pkgs(12).araddr),
               AXI_12_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_12_ARID         => i_read_pkgs(12).arid,
               AXI_12_ARLEN        => i_read_pkgs(12).arlen,
               AXI_12_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_12_ARVALID      => i_read_pkgs(12).arvalid,
               AXI_12_ARREADY      => o_read_pkgs(12).arready,
               AXI_12_AWADDR       => std_logic_vector(i_write_pkgs(12).awaddr),
               AXI_12_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_12_AWID         => i_write_pkgs(12).awid,
               AXI_12_AWLEN        => i_write_pkgs(12).awlen,
               AXI_12_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_12_AWVALID      => i_write_pkgs(12).awvalid,
               AXI_12_AWREADY      => o_write_pkgs(12).awready,
               AXI_12_RREADY       => i_read_pkgs(12).rready,
               AXI_12_BREADY       => i_write_pkgs(12).bready,
               AXI_12_WDATA        => i_write_pkgs(12).wdata,
               AXI_12_WLAST        => i_write_pkgs(12).wlast,
               AXI_12_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_12_WDATA_PARITY => i_write_pkgs(12).wdata_parity,
               AXI_12_WVALID       => i_write_pkgs(12).wvalid,
               AXI_12_RDATA_PARITY => o_read_pkgs(12).rdata_parity,
               AXI_12_RDATA        => o_read_pkgs(12).rdata,
               AXI_12_RID          => o_read_pkgs(12).rid,
               AXI_12_RLAST        => o_read_pkgs(12).rlast,
               AXI_12_RRESP        => o_read_pkgs(12).rresp,
               AXI_12_RVALID       => o_read_pkgs(12).rvalid,
               AXI_12_WREADY       => o_write_pkgs(12).wready,
               AXI_12_BID          => o_write_pkgs(12).bid,
               AXI_12_BRESP        => o_write_pkgs(12).bresp,
               AXI_12_BVALID       => o_write_pkgs(12).bvalid,

               AXI_13_ACLK         => i_clk,
               AXI_13_ARESET_N     => i_reset_n,
               AXI_13_ARADDR       => std_logic_vector(i_read_pkgs(13).araddr),
               AXI_13_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_13_ARID         => i_read_pkgs(13).arid,
               AXI_13_ARLEN        => i_read_pkgs(13).arlen,
               AXI_13_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_13_ARVALID      => i_read_pkgs(13).arvalid,
               AXI_13_ARREADY      => o_read_pkgs(13).arready,
               AXI_13_AWADDR       => std_logic_vector(i_write_pkgs(13).awaddr),
               AXI_13_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_13_AWID         => i_write_pkgs(13).awid,
               AXI_13_AWLEN        => i_write_pkgs(13).awlen,
               AXI_13_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_13_AWVALID      => i_write_pkgs(13).awvalid,
               AXI_13_AWREADY      => o_write_pkgs(13).awready,
               AXI_13_RREADY       => i_read_pkgs(13).rready,
               AXI_13_BREADY       => i_write_pkgs(13).bready,
               AXI_13_WDATA        => i_write_pkgs(13).wdata,
               AXI_13_WLAST        => i_write_pkgs(13).wlast,
               AXI_13_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_13_WDATA_PARITY => i_write_pkgs(13).wdata_parity,
               AXI_13_WVALID       => i_write_pkgs(13).wvalid,
               AXI_13_RDATA_PARITY => o_read_pkgs(13).rdata_parity,
               AXI_13_RDATA        => o_read_pkgs(13).rdata,
               AXI_13_RID          => o_read_pkgs(13).rid,
               AXI_13_RLAST        => o_read_pkgs(13).rlast,
               AXI_13_RRESP        => o_read_pkgs(13).rresp,
               AXI_13_RVALID       => o_read_pkgs(13).rvalid,
               AXI_13_WREADY       => o_write_pkgs(13).wready,
               AXI_13_BID          => o_write_pkgs(13).bid,
               AXI_13_BRESP        => o_write_pkgs(13).bresp,
               AXI_13_BVALID       => o_write_pkgs(13).bvalid,

               AXI_14_ACLK         => i_clk,
               AXI_14_ARESET_N     => i_reset_n,
               AXI_14_ARADDR       => std_logic_vector(i_read_pkgs(14).araddr),
               AXI_14_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_14_ARID         => i_read_pkgs(14).arid,
               AXI_14_ARLEN        => i_read_pkgs(14).arlen,
               AXI_14_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_14_ARVALID      => i_read_pkgs(14).arvalid,
               AXI_14_ARREADY      => o_read_pkgs(14).arready,
               AXI_14_AWADDR       => std_logic_vector(i_write_pkgs(14).awaddr),
               AXI_14_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_14_AWID         => i_write_pkgs(14).awid,
               AXI_14_AWLEN        => i_write_pkgs(14).awlen,
               AXI_14_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_14_AWVALID      => i_write_pkgs(14).awvalid,
               AXI_14_AWREADY      => o_write_pkgs(14).awready,
               AXI_14_RREADY       => i_read_pkgs(14).rready,
               AXI_14_BREADY       => i_write_pkgs(14).bready,
               AXI_14_WDATA        => i_write_pkgs(14).wdata,
               AXI_14_WLAST        => i_write_pkgs(14).wlast,
               AXI_14_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_14_WDATA_PARITY => i_write_pkgs(14).wdata_parity,
               AXI_14_WVALID       => i_write_pkgs(14).wvalid,
               AXI_14_RDATA_PARITY => o_read_pkgs(14).rdata_parity,
               AXI_14_RDATA        => o_read_pkgs(14).rdata,
               AXI_14_RID          => o_read_pkgs(14).rid,
               AXI_14_RLAST        => o_read_pkgs(14).rlast,
               AXI_14_RRESP        => o_read_pkgs(14).rresp,
               AXI_14_RVALID       => o_read_pkgs(14).rvalid,
               AXI_14_WREADY       => o_write_pkgs(14).wready,
               AXI_14_BID          => o_write_pkgs(14).bid,
               AXI_14_BRESP        => o_write_pkgs(14).bresp,
               AXI_14_BVALID       => o_write_pkgs(14).bvalid,

               AXI_15_ACLK         => i_clk,
               AXI_15_ARESET_N     => i_reset_n,
               AXI_15_ARADDR       => std_logic_vector(i_read_pkgs(15).araddr),
               AXI_15_ARBURST      => std_logic_vector(hbm_burstmode),
               AXI_15_ARID         => i_read_pkgs(15).arid,
               AXI_15_ARLEN        => i_read_pkgs(15).arlen,
               AXI_15_ARSIZE       => std_logic_vector(hbm_burstsize),
               AXI_15_ARVALID      => i_read_pkgs(15).arvalid,
               AXI_15_ARREADY      => o_read_pkgs(15).arready,
               AXI_15_AWADDR       => std_logic_vector(i_write_pkgs(15).awaddr),
               AXI_15_AWBURST      => std_logic_vector(hbm_burstmode),
               AXI_15_AWID         => i_write_pkgs(15).awid,
               AXI_15_AWLEN        => i_write_pkgs(15).awlen,
               AXI_15_AWSIZE       => std_logic_vector(hbm_burstsize),
               AXI_15_AWVALID      => i_write_pkgs(15).awvalid,
               AXI_15_AWREADY      => o_write_pkgs(15).awready,
               AXI_15_RREADY       => i_read_pkgs(15).rready,
               AXI_15_BREADY       => i_write_pkgs(15).bready,
               AXI_15_WDATA        => i_write_pkgs(15).wdata,
               AXI_15_WLAST        => i_write_pkgs(15).wlast,
               AXI_15_WSTRB        => std_logic_vector(hbm_strobe_setting),
               AXI_15_WDATA_PARITY => i_write_pkgs(15).wdata_parity,
               AXI_15_WVALID       => i_write_pkgs(15).wvalid,
               AXI_15_RDATA_PARITY => o_read_pkgs(15).rdata_parity,
               AXI_15_RDATA        => o_read_pkgs(15).rdata,
               AXI_15_RID          => o_read_pkgs(15).rid,
               AXI_15_RLAST        => o_read_pkgs(15).rlast,
               AXI_15_RRESP        => o_read_pkgs(15).rresp,
               AXI_15_RVALID       => o_read_pkgs(15).rvalid,
               AXI_15_WREADY       => o_write_pkgs(15).wready,
               AXI_15_BID          => o_write_pkgs(15).bid,
               AXI_15_BRESP        => o_write_pkgs(15).bresp,
               AXI_15_BVALID       => o_write_pkgs(15).bvalid,

               APB_0_PCLK          => i_clk_apb,
               APB_0_PRESET_N      => i_reset_n_apb,

               -- -- hbm read does not work if we don't drive these ports with zeros?
               -- APB_0_PWDATA        => (others => '0'),
               -- APB_0_PADDR         => (others => '0'),
               -- APB_0_PENABLE       => '0',
               -- APB_0_PSEL          => '0',
               -- APB_0_PWRITE        => '0',
               -- APB_0_PRDATA        => open,
               -- APB_0_PREADY        => open,
               -- APB_0_PSLVERR       => open,
               apb_complete_0      => o_initial_init_ready,
               DRAM_0_STAT_CATTRIP => open,
               DRAM_0_STAT_TEMP    => open
          );

end architecture;
