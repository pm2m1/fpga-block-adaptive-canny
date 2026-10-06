set project_name canny_a100t_phase6
set project_dir vivado/phase6_a100t
set part_name xc7a100tcsg324-1
set top_name canny_edge_detect_phase6_top
if {[file exists $project_dir]} { error "Refusing to overwrite $project_dir" }
file mkdir reports
file mkdir results/phase6
create_project $project_name $project_dir -part $part_name
set_property target_language Verilog [current_project]
set rtl_files [list \
    rtl/baseline/fifo_ram.v \
    rtl/baseline/one_column_ram.v \
    rtl/phase5b/matrix_generate_3x3_phase5b.v \
    rtl/phase5b/vip_gaussian_filter_phase5b.v \
    rtl/phase5b/canny_doubleThreshold_phase5b.v \
    rtl/phase4b/cordic_gradient_phase4b.v \
    rtl/phase5b/canny_nonLocalMaxValue_phase5b.v \
    rtl/phase6/canny_threshold_classify_phase6.v \
    rtl/phase6/canny_get_gradient_phase6.v \
    rtl/phase6/canny_edge_detect_phase6_top.v]
foreach rtl_file $rtl_files {
    if {![file exists $rtl_file]} { error "Missing RTL: $rtl_file" }
    add_files -fileset sources_1 $rtl_file
}
set_property top $top_name [get_filesets sources_1]
add_files -fileset constrs_1 constraints/phase2_core_timing.xdc
update_compile_order -fileset sources_1
if {[get_property PART [current_project]] ne $part_name ||
    [get_property top [get_filesets sources_1]] ne $top_name} {
    error "Part/top verification failed"
}
puts "PHASE6_PART=[get_property PART [current_project]]"
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "PHASE6_SYNTH_STATUS=$synth_status"
if {![string match "*Complete*" $synth_status]} { error "Synthesis failed" }
open_run synth_1
report_utilization -file reports/phase6_utilization.rpt
report_utilization -hierarchical -file reports/phase6_utilization_hierarchical.rpt
report_timing_summary -delay_type max -report_unconstrained -file reports/phase6_timing_synth.rpt
report_drc -file reports/phase6_drc_synth.rpt
set synth_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE6_SYNTH_WNS=$synth_wns"
if {$synth_wns < 0} { error "Synthesis WNS negative" }
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
set route_status [get_property STATUS [get_runs impl_1]]
puts "PHASE6_ROUTE_STATUS=$route_status"
if {![string match "*Complete*" $route_status]} { error "Implementation failed" }
open_run impl_1
report_timing_summary -delay_type max -report_unconstrained -file reports/phase6_timing_route.rpt
report_utilization -file reports/phase6_utilization_route.rpt
report_route_status -file reports/phase6_route_status.rpt
report_drc -file reports/phase6_drc.rpt
write_checkpoint results/phase6/canny_a100t_phase6_routed.dcp
set route_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE6_ROUTE_WNS=$route_wns"
if {$route_wns < 0} { error "Post-route WNS negative" }
puts "PHASE6_DONE=PASS"
