`default_nettype none
// One descending-bin scan step. `already_selected` is held by the scheduler.
module adaptive_threshold_step_phase8 (
    input wire [10:0] cumulative_i,
    input wire [10:0] bin_count_i,
    input wire [10:0] nonzero_i,
    input wire [4:0] bin_i,
    output wire [10:0] cumulative_o,
    output wire crossing_o,
    output wire [10:0] high_o,
    output wire [10:0] low_o
);
    assign cumulative_o=cumulative_i+bin_count_i;
    wire [13:0] five_cumulative={cumulative_o,2'b00}+{3'b000,cumulative_o};
    assign crossing_o=nonzero_i!=11'd0 && five_cumulative>={3'b000,nonzero_i};
    assign high_o=bin_i==5'd0 ? 11'd1 : {bin_i,6'b000000};
    // HIGH is at most 1984, 2*HIGH fits twelve bits; constant /5 maps to
    // combinational constant arithmetic and must be checked for timing.
    wire [11:0] double_high={high_o,1'b0};
    assign low_o=double_high/12'd5;
endmodule
`default_nettype wire
