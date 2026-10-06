file mkdir results/phase11v
file mkdir reports/phase11v
set synth [lindex [glob vivado/phase11_board_rev3/*.runs/synth_1/*.dcp] 0]
open_checkpoint $synth
puts "PHASE11V_SYNTH_PART=[get_property PART [current_design]]"
write_verilog -force -mode funcsim results/phase11v/post_synth_func.v
close_design
open_checkpoint results/phase11/canny_nexys_a7_phase11_rev3_routed.dcp
puts "PHASE11V_ROUTE_PART=[get_property PART [current_design]]"
write_verilog -force -mode funcsim results/phase11v/post_route_func.v
write_verilog -force -mode timesim -sdf_anno true results/phase11v/post_route_timesim.v
write_sdf -force -process_corner slow results/phase11v/post_route.sdf
set timing_netlist results/phase11v/post_route_timesim.v
set fp [open $timing_netlist r]
set body [read $fp]
close $fp
set old_anno {$sdf_annotate("post_route_timesim.sdf",,,,"tool_control")}
set new_anno {$sdf_annotate("results/phase11v/post_route.sdf",,,,"MAXIMUM")}
if {[string first $old_anno $body] < 0} {error "Expected generated SDF annotation not found"}
set fp [open $timing_netlist w]
puts -nonewline $fp [string map [list $old_anno $new_anno] $body]
close $fp
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 10 -file reports/phase11v/timing_summary.rpt
report_timing -delay_type max -max_paths 10 -file reports/phase11v/top10_setup.rpt
report_timing -delay_type min -max_paths 10 -file reports/phase11v/top10_hold.rpt
report_drc -file reports/phase11v/drc.rpt
report_utilization -hierarchical -file reports/phase11v/utilization_hierarchical.rpt
report_clock_utilization -file reports/phase11v/clock_utilization.rpt
report_exceptions -file reports/phase11v/timing_exceptions.rpt
set fp [open reports/phase11v/bram_cells.txt w]
set image_rom 0
set edge_buffer 0
set algorithm 0
set other 0
foreach cell [get_cells -hier -filter {REF_NAME == RAMB36E1}] {
    set name [get_property NAME $cell]
    puts $fp $name
    if {[string match *image_addr* $name]} {incr image_rom} elseif {[string match *edge_mem* $name]} {incr edge_buffer} elseif {[string match u_core/* $name]} {incr algorithm} else {incr other}
}
puts $fp "COUNTS image_rom=$image_rom edge_buffer=$edge_buffer algorithm=$algorithm other=$other"
close $fp
if {[catch {report_cdc -file reports/phase11v/cdc.rpt} cdc_err]} {
    puts "PHASE11V_CDC_REPORT_UNAVAILABLE=$cdc_err"
}
puts "PHASE11V_EXPORT_DONE"
