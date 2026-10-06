`default_nettype none
// Exactly the Phase 5B class/angle/magnitude packing; only thresholds vary.
module canny_threshold_classify_phase6 (
    input wire [10:0] magnitude,
    input wire [3:0] direction,
    input wire [10:0] threshold_low,
    input wire [10:0] threshold_high,
    output wire [16:0] gra_path
);
    assign gra_path = magnitude > threshold_high ?
        {2'b10, direction, magnitude} :
        magnitude > threshold_low ?
        {2'b01, direction, magnitude} : 17'd0;
endmodule
`default_nettype wire
