----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: big_add
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: outsourcing of bigger-than-DSP-size arithmetic operation
--             with additional registers, so that retiming can happen
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
     use work.datatypes_utils.all;

entity big_add is
     generic (
          substraction : boolean := false
     );
     port (
          i_clk  : in  std_ulogic;
          i_num0 : in  synthesiseable_int;
          i_num1 : in  synthesiseable_int;
          o_res  : out synthesiseable_int_extended
     );
end entity;

architecture Behavioral of big_add is
     signal reg_chain : wait_registers_int_extended(0 to (clks_per_64_bit_add-1*boolean'pos(big_add_in_buf)) - 1);
     signal num0_buf: synthesiseable_int;
     signal num1_buf: synthesiseable_int;

begin
     
     no_in_reg: if not big_add_in_buf generate
          num0_buf <= i_num0;
          num1_buf <= i_num1;
     end generate;

     in_reg: if big_add_in_buf generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    num0_buf <= i_num0;
                    num1_buf <= i_num1;
               end if;
          end process;
     end generate;

     add: if not substraction generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    reg_chain(0) <= to_synth_int_extended(num0_buf) + to_synth_int_extended(num1_buf);
               end if;
          end process;
     end generate;

     sub: if substraction generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    reg_chain(0) <= to_synth_int_extended(num0_buf) - to_synth_int_extended(num1_buf);
               end if;
          end process;
     end generate;

     reg_flow: if reg_chain'length > 1 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    reg_chain(1 to reg_chain'length - 1) <= reg_chain(0 to reg_chain'length - 2);
               end if;
          end process;
     end generate;

     o_res <= reg_chain(reg_chain'length - 1);

end architecture;
