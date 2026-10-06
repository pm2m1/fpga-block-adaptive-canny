set project_dir vivado/phase11_board_rev3
if {[file exists $project_dir]} {error "Refusing to overwrite $project_dir"}
create_project canny_nexys_a7_phase11_rev3 $project_dir -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]
set files [list \
  rtl/phase11/core/fifo_ram.v \
  rtl/phase11/core/one_column_ram.v \
  rtl/phase11/core/matrix_generate_3x3_phase5b.v \
  rtl/phase11/core/vip_gaussian_filter_phase5b.v \
  rtl/phase11/core/canny_doubleThreshold_phase5b.v \
  rtl/phase11/core/cordic_gradient_phase4b.v \
  rtl/phase11/core/canny_gradient_raw_phase8.v \
  rtl/phase11/core/canny_nms_magnitude_phase8.v \
  rtl/phase11/core/histogram_unit_phase9.v \
  rtl/phase11/core/adaptive_threshold_step_phase9.v \
  rtl/phase11/core/block_adaptive_engine_phase10.v \
  rtl/phase11/core/canny_block_adaptive_phase10_top.v \
  rtl/phase11/uart_tx_phase11.v \
  rtl/phase11/canny_nexys_a7_phase11_top.v]
foreach f $files {if {![file exists $f]} {error "Missing $f"}; add_files -fileset sources_1 $f}
set_property top canny_nexys_a7_phase11_top [get_filesets sources_1]
set_property generic {ROM_FILE=W:/images/phase11/monkey_gray.mem} [get_filesets sources_1]
add_files -fileset sources_1 images/phase11/monkey_gray.mem
add_files -fileset constrs_1 constraints/phase11/nexys_a7_100t_board.xdc
update_compile_order -fileset sources_1
if {[get_property PART [current_project]] ne "xc7a100tcsg324-1"} {error "Wrong part"}
file mkdir reports/phase11
file mkdir results/phase11
puts "PHASE11_PART=[get_property PART [current_project]]"
puts "PHASE11_TOP=[get_property top [get_filesets sources_1]]"
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set status [get_property STATUS [get_runs synth_1]]
puts "PHASE11_SYNTH_STATUS=$status"
if {![string match "*Complete*" $status]} {error "Synthesis failed"}
open_run synth_1
report_utilization -file reports/phase11/phase11_rev3_utilization_synth.rpt
report_utilization -hierarchical -file reports/phase11/phase11_rev3_utilization_hierarchical.rpt
report_timing_summary -delay_type max -report_unconstrained -max_paths 10 -file reports/phase11/phase11_rev3_timing_synth.rpt
report_drc -file reports/phase11/phase11_rev3_drc_synth.rpt
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
set status [get_property STATUS [get_runs impl_1]]
puts "PHASE11_ROUTE_STATUS=$status"
if {![string match "*Complete*" $status]} {error "Implementation failed"}
open_run impl_1
report_utilization -file reports/phase11/phase11_rev3_utilization_route.rpt
report_timing_summary -delay_type max -report_unconstrained -max_paths 10 -file reports/phase11/phase11_rev3_timing_route.rpt
report_route_status -file reports/phase11/phase11_rev3_route_status.rpt
report_drc -file reports/phase11/phase11_rev3_drc_route.rpt
report_power -file reports/phase11/phase11_rev3_power_vectorless.rpt
write_checkpoint results/phase11/canny_nexys_a7_phase11_rev3_routed.dcp
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "PHASE11_ROUTE_WNS=$wns"
puts "PHASE11_ROUTE_DONE"
