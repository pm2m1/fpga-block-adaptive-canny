set bitfile results/phase11/canny_nexys_a7.bit
if {![file exists $bitfile]} {error "Missing bitstream"}
open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets -quiet *]
if {[llength $targets] != 1} {error "Expected one connected JTAG target, found [llength $targets]"}
current_hw_target [lindex $targets 0]
open_hw_target
set devices [get_hw_devices -quiet *xc7a100t*]
if {[llength $devices] != 1} {error "Expected one XC7A100T, found [llength $devices]"}
set device [lindex $devices 0]
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device
refresh_hw_device $device
puts "PHASE11_PROGRAMMED_DEVICE=$device BITSTREAM=$bitfile"
close_hw_target
disconnect_hw_server
close_hw_manager
