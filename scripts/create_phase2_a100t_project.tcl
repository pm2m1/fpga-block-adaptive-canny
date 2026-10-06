# Execute from the protected workspace root (the Phase-2 PowerShell runner
# maps it to W: to avoid AMD's Windows batch-path parenthesis issue).
set project_name canny_a100t_baseline
set project_dir vivado/phase2_a100t_baseline
set part_name xc7a100tcsg324-1
set top_name canny_edge_detect_top

if {[file exists $project_dir]} {
    error "Refusing to overwrite existing Phase-2 project: $project_dir"
}
file mkdir reports
file mkdir results/phase2

create_project $project_name $project_dir -part $part_name
set_property target_language Verilog [current_project]

set rtl_files [list \
    rtl/baseline/fifo_ram.v \
    rtl/baseline/one_column_ram.v \
    rtl/baseline/matrix_generate_3x3.v \
    rtl/baseline/cordic_pipline.v \
    rtl/baseline/cordic_sqrt.v \
    rtl/baseline/vip_gaussian_filter.v \
    rtl/baseline/VIP_RGB888_YCbCr444.v \
    rtl/baseline/canny_get_grandient.v \
    rtl/baseline/canny_nonLocalMaxValue.v \
    rtl/baseline/canny_doubleThreshold.v \
    rtl/baseline/canny_edge_detect_top.v]
foreach rtl_file $rtl_files {
    if {![file exists $rtl_file]} { error "Missing baseline RTL: $rtl_file" }
    add_files -fileset sources_1 $rtl_file
}
set_property top $top_name [get_filesets sources_1]
add_files -fileset constrs_1 constraints/phase2_core_timing.xdc
update_compile_order -fileset sources_1

set actual_part [get_property PART [current_project]]
set actual_top [get_property top [get_filesets sources_1]]
puts "PHASE2_PROJECT_PART=$actual_part"
puts "PHASE2_SYNTH_TOP=$actual_top"
if {$actual_part ne $part_name || $actual_top ne $top_name} {
    error "Phase-2 part/top verification failed"
}
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "PHASE2_SYNTH_STATUS=$synth_status"
if {![string match "*Complete*" $synth_status]} {
    error "Phase-2 synthesis failed: $synth_status; inspect synth_1/runme.log"
}

open_run synth_1
puts "PHASE2_NETLIST_PART=[get_property PART [current_project]]"
puts "PHASE2_NETLIST_TOP=[get_property top [get_filesets sources_1]]"
report_utilization -file reports/phase2_utilization.rpt
report_utilization -hierarchical -file reports/phase2_utilization_hierarchical.rpt
report_timing_summary -delay_type max -report_unconstrained -file reports/phase2_timing_summary.rpt
report_drc -file reports/phase2_drc.rpt
write_checkpoint results/phase2/canny_a100t_baseline_synth.dcp

set run_log [file join $project_dir ${project_name}.runs synth_1 runme.log]
if {[file exists $run_log]} {
    file copy $run_log reports/phase2_synth_runme.log
}
puts "PHASE2_DONE=PASS"
