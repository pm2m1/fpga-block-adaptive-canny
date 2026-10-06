# Representative single-frame monkey processing activity only.
# UART is not captured here; its 3.3-second transfer is separate.
open_saif results/phase11/monkey_processing.saif
log_saif [get_objects -r *]
run -all
close_saif
quit
