if {[llength $argv] != 1} { error "Usage: -tclargs run_tag" }
set run_tag [lindex $argv 0]
if {![regexp {^run[0-9]+$} $run_tag]} { error "Unsafe run tag" }
set project_name canny_a100t_phase8_$run_tag
set project_dir vivado/phase8_a100t_$run_tag
set part_name xc7a100tcsg324-1
set top_name canny_block_adaptive_phase8_top
if {[file exists $project_dir]} { error "Refusing to overwrite $project_dir" }
file mkdir reports
file mkdir results/phase8
create_project $project_name $project_dir -part $part_name
set_property target_language Verilog [current_project]
set rtl_files [list \
    rtl/baseline/fifo_ram.v \
    rtl/baseline/one_column_ram.v \
    rtl/phase5b/matrix_generate_3x3_phase5b.v \
    rtl/phase5b/vip_gaussian_filter_phase5b.v \
    rtl/phase5b/canny_doubleThreshold_phase5b.v \
    rtl/phase4b/cordic_gradient_phase4b.v \
    rtl/phase8/canny_gradient_raw_phase8.v \
    rtl/phase8/canny_nms_magnitude_phase8.v \
    rtl/phase8/histogram_unit_phase8.v \
    rtl/phase8/adaptive_threshold_step_phase8.v \
    rtl/phase8/stripe_threshold_engine_phase8.v \
    rtl/phase8/canny_block_adaptive_phase8_top.v]
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
puts "PHASE8_PART=[get_property PART [current_project]]"
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "PHASE8_SYNTH_STATUS=$synth_status"
if {![string match "*Complete*" $synth_status]} { error "Synthesis failed" }
open_run synth_1
report_utilization -file reports/phase8_utilization.rpt
report_utilization -hierarchical -file reports/phase8_utilization_hierarchical.rpt
report_timing_summary -delay_type max -report_unconstrained -file reports/phase8_timing_synth.rpt
report_drc -file reports/phase8_drc_synth.rpt
set mem_fd [open reports/phase8_memory_inference.rpt w]
puts $mem_fd "Post-synthesis inferred memory primitives; inspect hierarchical utilization too."
foreach cell [get_cells -hier -filter {REF_NAME =~ RAMB* || REF_NAME =~ RAM32* || REF_NAME =~ RAM64*}] {
    puts $mem_fd "$cell [get_property REF_NAME $cell]"
}
close $mem_fd
set synth_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE8_SYNTH_WNS=$synth_wns"
if {$synth_wns < 0} { error "Synthesis WNS negative; inspect critical path" }
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
set route_status [get_property STATUS [get_runs impl_1]]
puts "PHASE8_ROUTE_STATUS=$route_status"
if {![string match "*Complete*" $route_status]} { error "Implementation failed" }
open_run impl_1
report_timing_summary -delay_type max -report_unconstrained -file reports/phase8_timing_route.rpt
report_utilization -file reports/phase8_utilization_route.rpt
report_route_status -file reports/phase8_route_status.rpt
report_drc -file reports/phase8_drc.rpt
write_checkpoint results/phase8/canny_a100t_phase8_routed.dcp
set route_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE8_ROUTE_WNS=$route_wns"
if {$route_wns < 0} { error "Post-route WNS negative; inspect critical path" }
puts "PHASE8_DONE=PASS"
