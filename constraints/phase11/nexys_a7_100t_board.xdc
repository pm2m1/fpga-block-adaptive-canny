# Selected used ports only, transcribed from Digilent's official
# Nexys-A7-100T-Master.xdc:
# https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc
# Do not substitute a Nexys A7-50T/Arty/USB104 pin map.
# Digilent's schematic ties configuration bank 0 to the 3.3 V rail;
# CFGBVS=VCCO selects that configuration-voltage range.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk100mhz]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0.000 5.000} [get_ports clk100mhz]

set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports cpu_resetn]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports start_btn]

set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports {test_sel[0]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVCMOS33} [get_ports {test_sel[1]}]
set_property -dict {PACKAGE_PIN M13 IOSTANDARD LVCMOS33} [get_ports {test_sel[2]}]

# Digilent UART_RXD_OUT is the FPGA output going to the host USB-UART RX.
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports uart_tx_o]

set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
