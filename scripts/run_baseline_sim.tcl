# XSim batch commands. Run from the Canny_BlockAdaptive_A100T workspace root.
# 640*480 active pixels at half-rate 6 ns clock; 670*510 pixel slots per frame.
# One frame period is 670*510*2*6 ns = 4.1004 ms. Two frames plus reset/latency
# fit within this 9 ms run. This script does not establish algorithm correctness.
run 9 ms
quit
