`timescale 1ns/1ps
module tb_phase9_histogram;
`ifdef PHASE9_B64
    localparam integer BLOCK=64;
`else
    localparam integer BLOCK=32;
`endif
`ifdef PHASE9_H8
    localparam integer BINS=8;
`elsif PHASE9_H16
    localparam integer BINS=16;
`else
    localparam integer BINS=32;
`endif
    localparam integer COLS=640/BLOCK;
    localparam integer ENTRIES=COLS*BINS;
    localparam integer ADDR_W=$clog2(ENTRIES);
    localparam integer COUNT_W=$clog2(BLOCK*BLOCK+1);
    reg clk=0,update_en=0,clear_en=0;
    reg [4:0] update_block=0;
    reg [10:0] magnitude=0;
    reg [ADDR_W-1:0] clear_addr=0,scan_addr=0;
    wire [COUNT_W-1:0] count,total;
    always #3 clk=~clk;
    histogram_unit_phase9 #(.BLOCK_W(BLOCK),.BLOCK_H(BLOCK),
        .HIST_BINS(BINS)) u_dut (
        .clk(clk),.update_en(update_en),.update_block(update_block),
        .update_magnitude(magnitude),.clear_en(clear_en),
        .clear_addr(clear_addr),.scan_addr(scan_addr),
        .scan_count(count),.scan_nonzero(total));
    integer i,nonzero;
    initial begin
        // Zero magnitudes do not enter any bin or the nonzero total.
        for (i=0;i<64;i=i+1) begin
            @(negedge clk);update_en=1;magnitude=0;
        end
        @(negedge clk);update_en=0;scan_addr=BINS-1;
        #1;if (count!==0 || total!==0) $fatal(1,"zeros were counted");
        // Maximum stress: all pixels hit one address back-to-back.
        for (i=0;i<BLOCK*BLOCK;i=i+1) begin
            @(negedge clk);update_en=1;magnitude=2047;
        end
        @(negedge clk);update_en=0;scan_addr=BINS-1;
        #1;if (count!==BLOCK*BLOCK || total!==BLOCK*BLOCK)
            $fatal(1,"same-bin count got=%0d total=%0d expected=%0d",
                   count,total,BLOCK*BLOCK);
        for (i=0;i<ENTRIES;i=i+1) begin
            @(negedge clk);clear_en=1;clear_addr=i;
        end
        @(negedge clk);clear_en=0;scan_addr=BINS-1;
        #1;if (count!==0 || total!==0) $fatal(1,"clear failed");
        // A final half-height 64-row stripe counts 2,048, never 4,096.
        nonzero=(BLOCK==64 ? 2048 : BLOCK*BLOCK);
        for (i=0;i<nonzero;i=i+1) begin
            @(negedge clk);update_en=1;magnitude=1;
        end
        @(negedge clk);update_en=0;scan_addr=0;
        #1;if (count!==nonzero || total!==nonzero)
            $fatal(1,"partial stripe count got=%0d total=%0d expected=%0d",
                   count,total,nonzero);
        $display("PHASE9_HISTOGRAM_PASS block=%0d bins=%0d full=%0d partial=%0d overflow=0 mismatches=0",
                 BLOCK,BINS,BLOCK*BLOCK,nonzero);
        $finish;
    end
endmodule
