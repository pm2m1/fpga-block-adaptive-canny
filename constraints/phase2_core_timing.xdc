# Phase 2 core-only 100 MHz assumption, NOT the final Nexys A7 board XDC.
# No package pins are assigned here. Input/output delays are not modeled.
# Timing results are preliminary core timing only, not board timing closure.
create_clock -name clk -period 10.000 [get_ports clk]
