set checkpoint results/phase11/canny_nexys_a7_phase11_rev3_routed.dcp
set bitfile results/phase11/canny_nexys_a7.bit
if {![file exists $checkpoint]} {error "Missing routed checkpoint"}
if {[file exists $bitfile]} {error "Refusing to overwrite existing bitstream"}
open_checkpoint $checkpoint
if {[get_property PART [current_design]] ne "xc7a100tcsg324-1"} {error "Wrong device"}
report_timing_summary -delay_type max -report_unconstrained -file reports/phase11/phase11_bitstream_gate_timing.rpt
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
if {$wns < 0} {error "Post-route timing fails: WNS=$wns"}
report_drc -file reports/phase11/phase11_bitstream_gate_drc.rpt
set violations [get_drc_violations]
if {[llength $violations] != 0} {error "DRC findings remain: [llength $violations]"}
write_bitstream $bitfile
puts "PHASE11_BITSTREAM_READY=$bitfile WNS=$wns"
