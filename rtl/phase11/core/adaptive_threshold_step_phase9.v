`default_nettype none
module adaptive_threshold_step_phase9 #(
    parameter integer HIST_BINS=32,
    parameter integer COUNT_W=11,
    parameter integer BIN_BITS=$clog2(HIST_BINS),
    parameter integer BIN_SHIFT=11-BIN_BITS
) (
    input wire [COUNT_W-1:0] cumulative_i,bin_count_i,nonzero_i,
    input wire [BIN_BITS-1:0] bin_i,
    output wire [COUNT_W-1:0] cumulative_o,
    output wire crossing_o,
    output wire [10:0] high_o,low_o
);
    assign cumulative_o=cumulative_i+bin_count_i;
    wire [COUNT_W+2:0] five_cumulative=
        {cumulative_o,2'b00}+{{2{1'b0}},cumulative_o};
    assign crossing_o=nonzero_i!={COUNT_W{1'b0}} &&
                      five_cumulative>={{3{1'b0}},nonzero_i};
    assign high_o=bin_i==0 ? 11'd1 : (bin_i << BIN_SHIFT);
    wire [11:0] double_high={high_o,1'b0};
    assign low_o=double_high/12'd5;
endmodule
`default_nettype wire
