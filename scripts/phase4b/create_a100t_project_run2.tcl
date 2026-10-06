set project_name canny_a100t_phase4b
set project_dir vivado/phase4b_a100t_timing_run2
set part_name xc7a100tcsg324-1
set top_name canny_edge_detect_phase4b_top
if {[file exists $project_dir]} { error "Refusing to overwrite $project_dir" }
file mkdir reports
file mkdir results/phase4b
create_project $project_name $project_dir -part $part_name
set_property target_language Verilog [current_project]
set rtl_files [list \
    rtl/baseline/fifo_ram.v \
    rtl/baseline/one_column_ram.v \
    rtl/baseline/matrix_generate_3x3.v \
    rtl/baseline/vip_gaussian_filter.v \
    rtl/baseline/canny_doubleThreshold.v \
    rtl/phase4b/cordic_gradient_phase4b.v \
    rtl/phase4b/canny_get_gradient_phase4b.v \
    rtl/phase4/canny_nonLocalMaxValue_phase4.v \
    rtl/phase4b/canny_edge_detect_phase4b_top.v]
foreach rtl_file $rtl_files {
    if {![file exists $rtl_file]} { error "Missing RTL: $rtl_file" }
    add_files -fileset sources_1 $rtl_file
}
set_property top $top_name [get_filesets sources_1]
add_files -fileset constrs_1 constraints/phase2_core_timing.xdc
update_compile_order -fileset sources_1
puts "PHASE4B_PROJECT_PART=[get_property PART [current_project]]"
puts "PHASE4B_SYNTH_TOP=[get_property top [get_filesets sources_1]]"
if {[get_property PART [current_project]] ne $part_name ||
    [get_property top [get_filesets sources_1]] ne $top_name} {
    error "Part/top verification failed"
}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set status [get_property STATUS [get_runs synth_1]]
puts "PHASE4B_SYNTH_STATUS=$status"
if {![string match "*Complete*" $status]} {
    error "Synthesis failed: $status"
}
open_run synth_1
puts "PHASE4B_NETLIST_PART=[get_property PART [current_project]]"
report_utilization -file reports/phase4b_run2_utilization.rpt
report_utilization -hierarchical -file reports/phase4b_run2_utilization_hierarchical.rpt
report_timing_summary -delay_type max -report_unconstrained -file reports/phase4b_run2_timing_summary.rpt
report_drc -file reports/phase4b_run2_drc.rpt
write_checkpoint results/phase4b/canny_a100t_phase4b_run2_synth.dcp
set synth_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE4B_SYNTH_WNS=$synth_wns"
if {$synth_wns < 0} { error "Synthesis timing failed at 10 ns: WNS=$synth_wns" }
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "PHASE4B_IMPL_STATUS=$impl_status"
if {![string match "*Complete*" $impl_status]} { error "Implementation failed: $impl_status" }
open_run impl_1
report_timing_summary -delay_type max -report_unconstrained -file reports/phase4b_run2_postroute_timing_summary.rpt
report_utilization -file reports/phase4b_run2_postroute_utilization.rpt
report_route_status -file reports/phase4b_run2_route_status.rpt
report_drc -file reports/phase4b_run2_postroute_drc.rpt
write_checkpoint results/phase4b/canny_a100t_phase4b_run2_routed.dcp
set route_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE4B_ROUTE_WNS=$route_wns"
if {$route_wns < 0} { error "Post-route timing failed at 10 ns: WNS=$route_wns" }
set run_log [file join $project_dir ${project_name}.runs synth_1 runme.log]
if {[file exists $run_log]} { file copy $run_log reports/phase4b_run2_synth_runme.log }
puts "PHASE4B_DONE=PASS"

