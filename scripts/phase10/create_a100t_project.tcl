if {[llength $argv] != 1} { error "Usage: -tclargs ENGINE_COUNT" }
set engines [lindex $argv 0]
if {$engines ni {1 2 4}} { error "ENGINE_COUNT must be 1,2,4" }
set tag "e${engines}"
set project_dir "vivado/phase10_${tag}"
if {[file exists $project_dir]} { error "Refusing to overwrite $project_dir" }
create_project "canny_a100t_phase10_${tag}" $project_dir -part xc7a100tcsg324-1
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
    rtl/phase10/block_adaptive_engine_phase10.v \
    rtl/phase10/canny_block_adaptive_phase10_top.v]
foreach f $files { if {![file exists $f]} {error "Missing RTL $f"}; add_files -fileset sources_1 $f }
set_property top canny_block_adaptive_phase10_top [get_filesets sources_1]
set_property generic "ENGINE_COUNT=$engines" [get_filesets sources_1]
add_files -fileset constrs_1 constraints/phase2_core_timing.xdc
update_compile_order -fileset sources_1
if {[get_property PART [current_project]] ne "xc7a100tcsg324-1"} {error "Wrong part"}
file mkdir reports/phase10
file mkdir results/phase10/checkpoints
puts "PHASE10_CONFIG=$tag PART=[get_property PART [current_project]] GENERIC=[get_property generic [get_filesets sources_1]]"
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set status [get_property STATUS [get_runs synth_1]]
puts "PHASE10_SYNTH_STATUS=$status"
if {![string match "*Complete*" $status]} { error "Synthesis failed $tag" }
open_run synth_1
report_utilization -file "reports/phase10/${tag}_utilization_synth.rpt"
report_utilization -hierarchical -file "reports/phase10/${tag}_utilization_hierarchical.rpt"
report_timing_summary -delay_type max -report_unconstrained -max_paths 10 -file "reports/phase10/${tag}_timing_synth.rpt"
report_drc -file "reports/phase10/${tag}_drc_synth.rpt"
set synth_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE10_SYNTH_WNS=$synth_wns"
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
set status [get_property STATUS [get_runs impl_1]]
puts "PHASE10_ROUTE_STATUS=$status"
if {![string match "*Complete*" $status]} { error "Implementation failed $tag" }
open_run impl_1
report_timing_summary -delay_type max -report_unconstrained -max_paths 10 -file "reports/phase10/${tag}_timing_route.rpt"
report_utilization -file "reports/phase10/${tag}_utilization_route.rpt"
report_route_status -file "reports/phase10/${tag}_route_status.rpt"
report_drc -file "reports/phase10/${tag}_drc_route.rpt"
write_checkpoint "results/phase10/checkpoints/${tag}_routed.dcp"
set route_wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE10_ROUTE_WNS=$route_wns"
puts "PHASE10_DONE=$tag"
