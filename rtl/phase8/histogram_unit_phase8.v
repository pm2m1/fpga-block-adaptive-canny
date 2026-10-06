`default_nettype none
// One 32-row stripe bank: 20 blocks * 32 bins * 11 bits = 7040 bits.
// Asynchronous read + synchronous write selects LUTRAM on Artix-7. One update
// per clock; a repeated address reads its prior registered write on the next
// cycle, so back-to-back same-bin samples increment without a BRAM hazard.
// Initial zero is a configuration-time FPGA RAM initialization, not a frame
// reset. Scheduler performs a synchronous 640-address clear before reuse.
module histogram_unit_phase8 (
    input wire clk,
    input wire update_en,
    input wire [4:0] update_block,
    input wire [10:0] update_magnitude,
    input wire clear_en,
    input wire [9:0] clear_addr,
    input wire [9:0] scan_addr,
    output wire [10:0] scan_count,
    output wire [10:0] scan_nonzero
);
    reg [10:0] hist [0:639];
    reg [10:0] nonzero_count [0:19];
    integer i;
    initial begin
        for (i=0;i<640;i=i+1) hist[i]=11'd0;
    end
    wire [9:0] update_addr={update_block,update_magnitude[10:6]};
    assign scan_count=hist[scan_addr];
    assign scan_nonzero=nonzero_count[scan_addr[9:5]];
    always @(posedge clk) begin
        if (clear_en)
            hist[clear_addr] <= 11'd0;
        else if (update_en && update_magnitude!=11'd0)
            hist[update_addr] <= hist[update_addr]+11'd1;
    end
    genvar block_id;
    generate for (block_id=0;block_id<20;block_id=block_id+1) begin: g_total
        localparam [4:0] BLOCK = block_id;
        initial nonzero_count[block_id]=11'd0;
        always @(posedge clk) begin
            if (clear_en && clear_addr=={BLOCK,5'b0})
                nonzero_count[block_id] <= 11'd0;
            else if (update_en && update_magnitude!=11'd0 && update_block==BLOCK)
                nonzero_count[block_id] <= nonzero_count[block_id]+11'd1;
        end
    end endgenerate
endmodule
`default_nettype wire
