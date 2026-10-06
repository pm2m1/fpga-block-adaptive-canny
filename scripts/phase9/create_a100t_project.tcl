if {[llength $argv] != 3} { error "Usage: -tclargs block bins route(0|1)" }
lassign $argv block bins route_it
if {$block ni {32 64} || $bins ni {8 16 32} || $route_it ni {0 1}} {
    error "Unsupported Phase9 configuration"
}
set tag "b${block}_h${bins}"
set project_dir "vivado/phase9_${tag}"
if {[file exists $project_dir]} { error "Refusing to overwrite $project_dir" }
create_project "canny_a100t_phase9_${tag}" $project_dir -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]
set files [list \
    rtl/baseline/fifo_ram.v \
    rtl/baseline/one_column_ram.v \
    rtl/phase5b/matrix_generate_3x3_phase5b.v \
    rtl/phase5b/vip_gaussian_filter_phase5b.v \
    rtl/phase5b/canny_doubleThreshold_phase5b.v \
    rtl/phase4b/cordic_gradient_phase4b.v \
    rtl/phase8/canny_gradient_raw_phase8.v \
    rtl/phase8/canny_nms_magnitude_phase8.v \
    rtl/phase9/histogram_unit_phase9.v \
    rtl/phase9/adaptive_threshold_step_phase9.v \
    rtl/phase9/stripe_threshold_engine_phase9.v \
    rtl/phase9/canny_block_adaptive_phase9_top.v]
foreach f $files { if {![file exists $f]} {error "Missing RTL $f"}; add_files -fileset sources_1 $f }
set_property top canny_block_adaptive_phase9_top [get_filesets sources_1]
set_property generic "BLOCK_W=$block BLOCK_H=$block HIST_BINS=$bins" [get_filesets sources_1]
add_files -fileset constrs_1 constraints/phase2_core_timing.xdc
update_compile_order -fileset sources_1
if {[get_property PART [current_project]] ne "xc7a100tcsg324-1"} {error "Wrong part"}
file mkdir reports/phase9
file mkdir results/phase9/checkpoints
puts "PHASE9_CONFIG=$tag PART=[get_property PART [current_project]] GENERIC=[get_property generic [get_filesets sources_1]]"
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set status [get_property STATUS [get_runs synth_1]]
puts "PHASE9_SYNTH_STATUS=$status"
if {![string match "*Complete*" $status]} { error "Synthesis failed $tag" }
open_run synth_1
report_utilization -file "reports/phase9/${tag}_utilization.rpt"
report_utilization -hierarchical -file "reports/phase9/${tag}_utilization_hierarchical.rpt"
report_timing_summary -delay_type max -report_unconstrained -file "reports/phase9/${tag}_timing_synth.rpt"
report_drc -file "reports/phase9/${tag}_drc_synth.rpt"
set fd [open "reports/phase9/${tag}_memory.rpt" w]
foreach cell [get_cells -hier -filter {REF_NAME =~ RAMB* || REF_NAME =~ RAM32* || REF_NAME =~ RAM64*}] {
    puts $fd "$cell [get_property REF_NAME $cell]"
}
close $fd
set synth_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE9_SYNTH_WNS=$synth_wns"
if {$route_it} {
    launch_runs impl_1 -to_step route_design -jobs 4
    wait_on_run impl_1
    set status [get_property STATUS [get_runs impl_1]]
    puts "PHASE9_ROUTE_STATUS=$status"
    if {![string match "*Complete*" $status]} { error "Implementation failed $tag" }
    open_run impl_1
    report_timing_summary -delay_type max -report_unconstrained -file "reports/phase9/${tag}_timing_route.rpt"
    report_utilization -file "reports/phase9/${tag}_utilization_route.rpt"
    report_route_status -file "reports/phase9/${tag}_route_status.rpt"
    report_drc -file "reports/phase9/${tag}_drc_route.rpt"
    write_checkpoint "results/phase9/checkpoints/${tag}_routed.dcp"
    set route_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
    puts "PHASE9_ROUTE_WNS=$route_wns"
}
puts "PHASE9_DONE=$tag"
