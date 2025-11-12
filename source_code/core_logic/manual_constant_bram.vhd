----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: manual_constant_bram
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: component that vivado implements using bram
-- Dependencies: see imports
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.NUMERIC_STD.all;
library work;
     use work.datatypes_utils.all;
     use work.constants_utils.all;
     use work.ntt_utils.all;

entity manual_constant_bram is
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
end entity;

architecture Behavioral of manual_constant_bram is

     signal out_bufs : sub_polynom(0 to ram_out_bufs_length - 1);
     -- the ram content still has the old indices --> need to zero them
     constant internal_ram_content : sub_polynom(0 to ram_content'length-1) := zero_indices(ram_content);
     signal ram : sub_polynom(0 to internal_ram_content'length - 1) := internal_ram_content;

     attribute ram_style        : string; -- options: block, distributed, registers, ultra
     attribute ram_style of ram : signal is ram_type;

begin

     read_logic: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               out_bufs(0) <= ram(to_integer(i_rd_addr));
               out_bufs(1 to out_bufs'length - 1) <= out_bufs(0 to out_bufs'length - 2);
          end if;
     end process;
     o_data <= out_bufs(out_bufs'length - 1);

end architecture;
