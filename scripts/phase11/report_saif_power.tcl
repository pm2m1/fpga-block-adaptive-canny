set checkpoint results/phase11/canny_nexys_a7_phase11_rev3_routed.dcp
set saif results/phase11/monkey_processing.saif
if {![file exists $checkpoint] || ![file exists $saif]} {error "Need routed checkpoint and SAIF"}
open_checkpoint $checkpoint
read_saif -strip_path tb_board_wrapper/dut -out_file reports/phase11/phase11_saif_unmatched.rpt $saif
report_power -file reports/phase11/phase11_power_saif.rpt
puts "PHASE11_SAIF_POWER_DONE"
