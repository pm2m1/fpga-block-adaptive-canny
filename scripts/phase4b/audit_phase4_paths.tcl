open_checkpoint results/phase4/canny_a100t_cordic_fixed_synth.dcp
puts "PHASE4B_AUDIT_PART=[get_property PART [current_project]]"
puts "PHASE4B_AUDIT_CLOCK_PERIOD=[get_property PERIOD [get_clocks clk]]"
report_timing -delay_type max -max_paths 10 -path_type full_clock_expanded -file reports/phase4b_phase4_top10_timing.rpt
puts "PHASE4B_AUDIT_DONE=PASS"
