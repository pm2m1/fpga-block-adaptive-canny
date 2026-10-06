open_hw_manager
if {[catch {connect_hw_server -url localhost:3121} msg]} {
    puts "PHASE11_HARDWARE_SERVER_UNAVAILABLE=$msg"
    exit 0
}
set targets [get_hw_targets -quiet *]
puts "PHASE11_HW_TARGET_COUNT=[llength $targets]"
foreach target $targets {
    if {[catch {open_hw_target $target} msg]} {
        puts "PHASE11_HW_TARGET_OPEN_FAIL=$target $msg"
    } else {
        puts "PHASE11_HW_TARGET=$target DEVICES=[get_hw_devices *]"
    }
}
disconnect_hw_server
close_hw_manager
