----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 08:14:04
-- Design Name: 
-- Module Name: top_tfhe_processor - Behavioral
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
     port (
          clk_pin_p          : in STD_LOGIC;
          clk_pin_n          : in STD_LOGIC;
          clk2_pin_p         : in STD_LOGIC;
          clk3_pin_p         : in STD_LOGIC;
          pcie_ref_clk_pin_p : in STD_LOGIC;
          pcie_ref_clk_pin_n : in STD_LOGIC
               -- gty_ref_clk_pin_p : in STD_LOGIC;
               -- gty_ref_clk_pin_n : in STD_LOGIC;
               -- gty_clk_pin_p     : in STD_LOGIC;
               -- gty_clk_pin_n     : in STD_LOGIC
     );
end entity;

architecture Behavioral of top is

     component tfhe_processor is
          port (
               i_sys_clk      : in std_ulogic;
               i_clk_ref      : in std_ulogic; -- for hbm stack 0
               i_clk_ref_2    : in std_ulogic; -- for hbm stack 1
               i_clk_apb      : in std_ulogic; -- for both hbm stacks
               -- i_reset_n_apb  : in std_ulogic; -- for both hbm stacks
               i_sys_clk_pcie : in std_ulogic; -- 100 MHz
               i_sys_clk_gt   : in std_ulogic  -- 100 MHz, must be directly driven from BUFDS_GTE
               -- i_reset_n      : in std_ulogic
          );
     end component;

     component clk_wiz_0 is
          port (clk_in1_p : in  std_logic;
                clk_in1_n : in  std_logic;
                clk_out1  : out std_logic;
                clk_out2  : out std_logic;
                clk_out3  : out std_logic
               );
     end component;

     -- clock and controls
     signal clk_signal            : std_logic;
     signal clk_signal_ref        : std_ulogic;
     signal clk_signal_ref_2      : std_ulogic;
     signal clk_signal_ref_pcie   : std_ulogic; -- v4p ignore w-302
     signal clk_signal_apb_driver : std_ulogic;
     signal clk_signal_apb        : std_ulogic; -- v4p ignore w-302

begin

     -- define the buffers for the incoming data, clocks, and control
     clk_core_inst_0: clk_wiz_0
          port map (
               clk_in1_p => clk_pin_p, --gty_clk_pin_p, -- TODO: should be gty_clk_pin_p but then vivado synthesises the computing module away
               clk_in1_n => clk_pin_n, --gty_clk_pin_n, -- TODO: should be gty_clk_pin_n but then vivado synthesises the computing module away
               -- clk_in1_p => gty_clk_pin_p,
               -- clk_in1_n => gty_clk_pin_n,
               clk_out1  => clk_signal,
               clk_out2  => clk_signal_apb_driver,
               clk_out3  => open --clk_signal_ref_pcie
          );
     clk_signal_ref   <= clk2_pin_p;
     clk_signal_ref_2 <= clk3_pin_p;

     -- general high fanout buffer, its input is the output of IBUFG
     BUFG_clk_inst: BUFG -- v4p ignore E-202
          port map (
               O => clk_signal_apb, -- 1-bit output: Clock output.
               I => clk_signal_apb_driver -- 1-bit input: Clock input.
          );
     IBUFDS_inst: IBUFDS -- v4p ignore E-202
     -- generic map (
     --      DIFF_TERM    => FALSE, -- Differential Termination
     --      IBUF_LOW_PWR => TRUE,  -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
     --      IOSTANDARD   => "DEFAULT"
     -- )
     port map (
          O  => clk_signal_ref_pcie,
          I  => pcie_ref_clk_pin_p,
          IB => pcie_ref_clk_pin_n
     );

     -- clk_signal_ref_pcie <= clk_signal_apb_driver;

     -- the main code
     my_tfhe_processor_inst: tfhe_processor
          port map (
               i_sys_clk      => clk_signal_ref_pcie, -- same frequency as gt
               i_clk_ref      => clk_signal_ref,
               i_clk_ref_2    => clk_signal_ref_2,
               i_clk_apb      => clk_signal_apb_driver,
               -- i_reset_n_apb  => '1',
               i_sys_clk_pcie => clk_signal_ref_pcie, -- same frequency as gt
               i_sys_clk_gt   => clk_signal_ref_pcie --, -- 100 MHz, must be directly driven from BUFDS_GTE
                    -- i_reset_n      => reset_n
          );

end architecture;
