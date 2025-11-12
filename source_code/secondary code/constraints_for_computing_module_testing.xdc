# create_clock -period 5.000 -name clk_pin_p -waveform {0.000 2.500} [get_ports clk_pin_p]
set_output_delay -clock [get_clocks clk_pin_p] 1.000 [get_ports led_pins*]

## CLK
#set_property IOSTANDARD LVDS [get_ports clk_pin_p]
#set_property IOSTANDARD LVDS [get_ports clk_pin_n]
##set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property PACKAGE_PIN F35 [get_ports clk_pin_p]
set_property PACKAGE_PIN F36 [get_ports clk_pin_n]
set_property CFGBVS GND [current_design]


## LED
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[7]}]

set_property PACKAGE_PIN BH24 [get_ports {led_pins[0]}]
set_property PACKAGE_PIN BG24 [get_ports {led_pins[1]}]
set_property PACKAGE_PIN BG25 [get_ports {led_pins[2]}]
set_property PACKAGE_PIN BF25 [get_ports {led_pins[3]}]
set_property PACKAGE_PIN BF26 [get_ports {led_pins[4]}]
set_property PACKAGE_PIN BF27 [get_ports {led_pins[5]}]
set_property PACKAGE_PIN BG27 [get_ports {led_pins[6]}]
set_property PACKAGE_PIN BG28 [get_ports {led_pins[7]}]

set_false_path -from [get_pins {led_o_buffer_reg[0]/C}] -to [get_ports {led_pins[0]}]
set_false_path -from [get_pins {led_o_buffer_reg[1]/C}] -to [get_ports {led_pins[1]}]
set_false_path -from [get_pins {led_o_buffer_reg[2]/C}] -to [get_ports {led_pins[2]}]
set_false_path -from [get_pins {led_o_buffer_reg[3]/C}] -to [get_ports {led_pins[3]}]
set_false_path -from [get_pins {led_o_buffer_reg[4]/C}] -to [get_ports {led_pins[4]}]
set_false_path -from [get_pins {led_o_buffer_reg[5]/C}] -to [get_ports {led_pins[5]}]
set_false_path -from [get_pins {led_o_buffer_reg[6]/C}] -to [get_ports {led_pins[6]}]
set_false_path -from [get_pins {led_o_buffer_reg[7]/C}] -to [get_ports {led_pins[7]}]
