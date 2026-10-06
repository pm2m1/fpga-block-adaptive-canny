`default_nettype none
// One stripe histogram bank. Nonzero post-NMS magnitudes only. Async LUTRAM
// read and synchronous write permit consecutive same-address increments.
module histogram_unit_phase9 #(
    parameter integer BLOCK_W=32,
    parameter integer BLOCK_H=32,
    parameter integer HIST_BINS=32,
    parameter integer BLOCK_COLS=640/BLOCK_W,
    parameter integer BIN_BITS=$clog2(HIST_BINS),
    parameter integer HIST_ENTRIES=BLOCK_COLS*HIST_BINS,
    parameter integer ADDR_W=$clog2(HIST_ENTRIES),
    parameter integer COUNT_W=$clog2(BLOCK_W*BLOCK_H+1)
) (
    input wire clk,
    input wire update_en,
    input wire [4:0] update_block,
    input wire [10:0] update_magnitude,
    input wire clear_en,
    input wire [ADDR_W-1:0] clear_addr,scan_addr,
    output wire [COUNT_W-1:0] scan_count,scan_nonzero
);
    localparam integer BIN_SHIFT=11-BIN_BITS;
    reg [COUNT_W-1:0] hist [0:HIST_ENTRIES-1];
    reg [COUNT_W-1:0] nonzero_count [0:BLOCK_COLS-1];
    integer i;
    initial for (i=0;i<HIST_ENTRIES;i=i+1) hist[i]={COUNT_W{1'b0}};
    wire [ADDR_W-1:0] update_addr=
        (update_block << BIN_BITS) | (update_magnitude >> BIN_SHIFT);
    assign scan_count=hist[scan_addr];
    assign scan_nonzero=nonzero_count[scan_addr >> BIN_BITS];
    always @(posedge clk) begin
        if (clear_en) hist[clear_addr]<={COUNT_W{1'b0}};
        else if (update_en && update_magnitude!=11'd0)
            hist[update_addr]<=hist[update_addr]+{{(COUNT_W-1){1'b0}},1'b1};
    end
    genvar b;
    generate for (b=0;b<BLOCK_COLS;b=b+1) begin:g_total
        initial nonzero_count[b]={COUNT_W{1'b0}};
        always @(posedge clk) begin
            if (clear_en && clear_addr==(b << BIN_BITS))
                nonzero_count[b]<={COUNT_W{1'b0}};
            else if (update_en && update_magnitude!=11'd0 && update_block==b)
                nonzero_count[b]<=nonzero_count[b]+{{(COUNT_W-1){1'b0}},1'b1};
        end
    end endgenerate
`ifndef SYNTHESIS
    initial if (BLOCK_W!=32 && BLOCK_W!=64 ||
                BLOCK_H!=BLOCK_W ||
                (HIST_BINS!=8 && HIST_BINS!=16 && HIST_BINS!=32))
        $fatal(1,"unsupported Phase9 histogram parameters");
    always @(posedge clk) if (update_en && update_magnitude!=0) begin
        if (update_block>=BLOCK_COLS) $fatal(1,"invalid block index");
        if (hist[update_addr]>=BLOCK_W*BLOCK_H) $fatal(1,"hist overflow");
        if (nonzero_count[update_block]>=BLOCK_W*BLOCK_H)
            $fatal(1,"nonzero overflow");
    end
`endif
endmodule
`default_nettype wire
