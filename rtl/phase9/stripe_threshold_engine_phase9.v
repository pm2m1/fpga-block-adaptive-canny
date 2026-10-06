`default_nettype none
// Post-NMS full-raster stripe buffering; only threshold statistics are local.
// 32-row stripes use two banks. A 64-row frame ends with 32 rows, so three
// banks are mandatory at the tested 640+24-clock/line source cadence.
module stripe_threshold_engine_phase9 #(
    parameter integer BLOCK_W=32,
    parameter integer BLOCK_H=32,
    parameter integer HIST_BINS=32,
    parameter integer BANKS=(BLOCK_H==64 ? 3 : 2),
    parameter integer BLOCK_COLS=640/BLOCK_W,
    parameter integer BLOCK_ROWS=(480+BLOCK_H-1)/BLOCK_H,
    parameter integer LAST_ROWS=480-(BLOCK_ROWS-1)*BLOCK_H,
    parameter integer BIN_BITS=$clog2(HIST_BINS),
    parameter integer BLOCK_SHIFT=$clog2(BLOCK_W),
    parameter integer HIST_ENTRIES=BLOCK_COLS*HIST_BINS,
    parameter integer ADDR_W=$clog2(HIST_ENTRIES),
    parameter integer COUNT_W=$clog2(BLOCK_W*BLOCK_H+1),
    parameter integer STRIPE_SAMPLES=640*BLOCK_H
) (
    input wire clk,rst_n,
    input wire nms_vs,nms_hs,nms_de,
    input wire [10:0] nms_magnitude,
    input wire mode_active,
    input wire [10:0] fixed_low_active,fixed_high_active,
    output reg class_vs,class_hs,class_de,
    output reg [1:0] class_value
);
    localparam [1:0] SCAN_IDLE=2'd0,SCAN_BINS=2'd1,
                     SCAN_CLEAR=2'd2,SCAN_DRAIN=2'd3;
    localparam [BIN_BITS-1:0] LAST_BIN=HIST_BINS-1;
    wire input_valid=nms_hs && nms_de;
    reg [1:0] fill_bank,scan_bank,scan_expect_bank,replay_bank,replay_expect_bank;
    reg [9:0] fill_x,replay_x;
    reg [5:0] fill_row,replay_row;
    reg [3:0] fill_stripe;
    reg nms_vs_d;
    reg replay_active,replay_gap;
    wire [5:0] fill_last_row=fill_stripe==BLOCK_ROWS-1 ? LAST_ROWS-1 : BLOCK_H-1;
    wire [4:0] fill_block=fill_x >> BLOCK_SHIFT;
    wire [15:0] fill_addr=({fill_row,9'b0}+{fill_row,7'b0})+{6'b0,fill_x};
    wire [15:0] read_addr=({replay_row,9'b0}+{replay_row,7'b0})+{6'b0,replay_x};
    wire read_request=replay_active && !replay_gap;
    wire [10:0] read_data [0:BANKS-1];
    wire [COUNT_W-1:0] hist_count [0:BANKS-1];
    wire [COUNT_W-1:0] hist_nonzero [0:BANKS-1];
    reg [BANKS-1:0] bank_free,bank_complete,bank_ready,bank_cleared,bank_replayed;
    reg bank_mode [0:BANKS-1];
    reg [10:0] bank_fixed_low [0:BANKS-1],bank_fixed_high [0:BANKS-1];
    reg [3:0] bank_stripe [0:BANKS-1];
    reg [10:0] block_low [0:BANKS-1][0:BLOCK_COLS-1];
    reg [10:0] block_high [0:BANKS-1][0:BLOCK_COLS-1];
    reg block_active [0:BANKS-1][0:BLOCK_COLS-1];
    reg [BIN_BITS-1:0] block_bin [0:BANKS-1][0:BLOCK_COLS-1];

    reg [1:0] scan_state;
    reg [ADDR_W-1:0] scan_index;
    reg [COUNT_W-1:0] cumulative;
    reg selected;
    reg scan_valid_pipe,scan_first_pipe;
    reg [4:0] scan_block_pipe;
    reg [BIN_BITS-1:0] scan_bin_pipe;
    reg [COUNT_W-1:0] scan_count_pipe,scan_nonzero_pipe;
    wire [BIN_BITS-1:0] scan_bin=LAST_BIN-scan_index[BIN_BITS-1:0];
    wire [ADDR_W-1:0] scan_hist_addr=
        (scan_index & ~((1 << BIN_BITS)-1)) | scan_bin;
    wire scan_clear=scan_state==SCAN_CLEAR;
    wire [COUNT_W-1:0] cumulative_input=scan_first_pipe ? 0:cumulative;
    wire [COUNT_W-1:0] cumulative_next;
    wire [10:0] step_high,step_low;
    wire crossing;
    adaptive_threshold_step_phase9 #(.HIST_BINS(HIST_BINS),.COUNT_W(COUNT_W)) u_step (
        .cumulative_i(cumulative_input),.bin_count_i(scan_count_pipe),
        .nonzero_i(scan_nonzero_pipe),.bin_i(scan_bin_pipe),
        .cumulative_o(cumulative_next),.crossing_o(crossing),
        .high_o(step_high),.low_o(step_low));

    genvar bank_id;
    generate for (bank_id=0;bank_id<BANKS;bank_id=bank_id+1) begin:g_bank
        reg [10:0] stripe [0:STRIPE_SAMPLES-1];
        reg [10:0] stripe_read;
        always @(posedge clk) begin
            if (input_valid && fill_bank==bank_id)
                stripe[fill_addr]<=nms_magnitude;
            if (read_request && replay_bank==bank_id)
                stripe_read<=stripe[read_addr];
        end
        assign read_data[bank_id]=stripe_read;
        histogram_unit_phase9 #(.BLOCK_W(BLOCK_W),.BLOCK_H(BLOCK_H),
            .HIST_BINS(HIST_BINS)) u_hist (
            .clk(clk),.update_en(input_valid && fill_bank==bank_id),
            .update_block(fill_block),.update_magnitude(nms_magnitude),
            .clear_en(scan_clear && scan_bank==bank_id),
            .clear_addr(scan_index),.scan_addr(scan_hist_addr),
            .scan_count(hist_count[bank_id]),
            .scan_nonzero(hist_nonzero[bank_id]));
    end endgenerate

    reg read_valid;
    reg [1:0] read_bank_d;
    reg read_first_frame,read_final_frame,read_last_stripe;
    reg [4:0] read_block;
    reg end_frame_pending;
    wire [5:0] replay_last_row=bank_stripe[replay_bank]==BLOCK_ROWS-1 ?
                               LAST_ROWS-1 : BLOCK_H-1;
    wire [10:0] read_magnitude=read_data[read_bank_d];
    wire [10:0] chosen_low=bank_mode[read_bank_d] ?
        block_low[read_bank_d][read_block]:bank_fixed_low[read_bank_d];
    wire [10:0] chosen_high=bank_mode[read_bank_d] ?
        block_high[read_bank_d][read_block]:bank_fixed_high[read_bank_d];
    wire chosen_active=bank_mode[read_bank_d] ?
        block_active[read_bank_d][read_block]:1'b1;

    function [1:0] next_bank;
        input [1:0] bank;
        begin next_bank=bank==BANKS-1 ? 2'd0:bank+2'd1; end
    endfunction

    integer i,j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fill_bank<=0;fill_x<=0;fill_row<=0;fill_stripe<=0;nms_vs_d<=0;
            scan_state<=SCAN_IDLE;scan_bank<=0;scan_expect_bank<=0;
            scan_index<=0;cumulative<=0;selected<=0;
            scan_valid_pipe<=0;scan_first_pipe<=0;
            scan_block_pipe<=0;scan_bin_pipe<=0;
            scan_count_pipe<=0;scan_nonzero_pipe<=0;
            replay_active<=0;replay_bank<=0;replay_expect_bank<=0;
            replay_gap<=0;replay_x<=0;replay_row<=0;
            read_valid<=0;read_bank_d<=0;read_first_frame<=0;
            read_final_frame<=0;read_last_stripe<=0;read_block<=0;
            class_vs<=0;class_hs<=0;class_de<=0;class_value<=0;
            end_frame_pending<=0;
            bank_free<={BANKS{1'b1}};bank_complete<=0;
            bank_ready<=0;bank_cleared<={BANKS{1'b1}};
            bank_replayed<={BANKS{1'b1}};
            for (i=0;i<BANKS;i=i+1) begin
                bank_mode[i]<=0;bank_fixed_low[i]<=11'd50;
                bank_fixed_high[i]<=11'd100;bank_stripe[i]<=0;
                for (j=0;j<BLOCK_COLS;j=j+1) begin
                    block_low[i][j]<=0;block_high[i][j]<=0;
                    block_active[i][j]<=0;block_bin[i][j]<=0;
                end
            end
        end else begin
            nms_vs_d<=nms_vs;
            if (nms_vs && !nms_vs_d) fill_stripe<=0;
            if (input_valid) begin
                if (fill_x==0 && fill_row==0) begin
                    bank_free[fill_bank]<=0;bank_cleared[fill_bank]<=0;
                    bank_replayed[fill_bank]<=0;
                    bank_mode[fill_bank]<=mode_active;
                    bank_fixed_low[fill_bank]<=fixed_low_active;
                    bank_fixed_high[fill_bank]<=fixed_high_active;
                    bank_stripe[fill_bank]<=nms_vs && !nms_vs_d ? 0:fill_stripe;
                end
                if (fill_x==10'd639) begin
                    fill_x<=0;
                    if (fill_row==fill_last_row) begin
                        fill_row<=0;
                        fill_stripe<=fill_stripe==BLOCK_ROWS-1 ? 0:fill_stripe+4'd1;
                        bank_complete[fill_bank]<=1;
                        fill_bank<=next_bank(fill_bank);
                    end else fill_row<=fill_row+6'd1;
                end else fill_x<=fill_x+10'd1;
            end
            scan_valid_pipe<=scan_state==SCAN_BINS;
            if (scan_state==SCAN_BINS) begin
                scan_count_pipe<=hist_count[scan_bank];
                scan_nonzero_pipe<=hist_nonzero[scan_bank];
                scan_block_pipe<=scan_index >> BIN_BITS;
                scan_bin_pipe<=scan_bin;
                scan_first_pipe<=scan_index[BIN_BITS-1:0]==0;
            end
            if (scan_valid_pipe &&
                (scan_state==SCAN_BINS || scan_state==SCAN_DRAIN)) begin
                cumulative<=cumulative_next;
                if (scan_first_pipe) begin
                    selected<=0;
                    block_active[scan_bank][scan_block_pipe]<=0;
                    block_low[scan_bank][scan_block_pipe]<=0;
                    block_high[scan_bank][scan_block_pipe]<=0;
                    block_bin[scan_bank][scan_block_pipe]<=0;
                end
                if (crossing && (scan_first_pipe || !selected)) begin
                    selected<=1;
                    block_active[scan_bank][scan_block_pipe]<=1;
                    block_low[scan_bank][scan_block_pipe]<=step_low;
                    block_high[scan_bank][scan_block_pipe]<=step_high;
                    block_bin[scan_bank][scan_block_pipe]<=scan_bin_pipe;
                end
            end
            case (scan_state)
                SCAN_IDLE: if (bank_complete[scan_expect_bank]) begin
                    scan_bank<=scan_expect_bank;
                    bank_complete[scan_expect_bank]<=0;
                    scan_expect_bank<=next_bank(scan_expect_bank);
                    scan_index<=0;cumulative<=0;selected<=0;
                    scan_state<=SCAN_BINS;
                end
                SCAN_BINS: if (scan_index==HIST_ENTRIES-1) begin
                    scan_index<=0;scan_state<=SCAN_DRAIN;
                end else scan_index<=scan_index+1'b1;
                SCAN_DRAIN: begin
                    scan_index<=0;scan_state<=SCAN_CLEAR;
                    bank_ready[scan_bank]<=1;
                end
                SCAN_CLEAR: if (scan_index==HIST_ENTRIES-1) begin
                    scan_index<=0;scan_state<=SCAN_IDLE;
                    bank_cleared[scan_bank]<=1;
                end else scan_index<=scan_index+1'b1;
                default: scan_state<=SCAN_IDLE;
            endcase
            if (!replay_active && bank_ready[replay_expect_bank]) begin
                replay_active<=1;
                replay_bank<=replay_expect_bank;
                bank_ready[replay_expect_bank]<=0;
                replay_x<=0;replay_row<=0;replay_gap<=0;
            end else if (replay_active) begin
                if (replay_gap) replay_gap<=0;
                else if (replay_x==10'd639) begin
                    replay_x<=0;
                    if (replay_row==replay_last_row) begin
                        replay_row<=0;replay_active<=0;
                        replay_expect_bank<=next_bank(replay_expect_bank);
                    end else begin
                        replay_row<=replay_row+6'd1;replay_gap<=1;
                    end
                end else replay_x<=replay_x+10'd1;
            end
            read_valid<=read_request;
            if (read_request) begin
                read_bank_d<=replay_bank;
                read_block<=replay_x >> BLOCK_SHIFT;
                read_first_frame<=bank_stripe[replay_bank]==0 &&
                                  replay_row==0 && replay_x==0;
                read_final_frame<=bank_stripe[replay_bank]==BLOCK_ROWS-1 &&
                                  replay_row==replay_last_row && replay_x==10'd639;
                read_last_stripe<=replay_row==replay_last_row && replay_x==10'd639;
            end else begin
                read_first_frame<=0;read_final_frame<=0;read_last_stripe<=0;
            end
            class_hs<=read_valid;class_de<=read_valid;
            if (read_valid)
                class_value<=!chosen_active ? 2'd0 :
                    read_magnitude>chosen_high ? 2'd2 :
                    read_magnitude>chosen_low ? 2'd1 : 2'd0;
            else class_value<=0;
            if (read_valid && read_first_frame) class_vs<=1;
            else if (end_frame_pending) class_vs<=0;
            end_frame_pending<=read_valid && read_final_frame;
            if (read_valid && read_last_stripe) bank_replayed[read_bank_d]<=1;
            for (i=0;i<BANKS;i=i+1)
                if (bank_cleared[i] && bank_replayed[i] &&
                    !(input_valid && fill_bank==i && fill_x==0 && fill_row==0))
                    bank_free[i]<=1;
        end
    end
`ifndef SYNTHESIS
    initial if ((BLOCK_W!=32 && BLOCK_W!=64) || BLOCK_H!=BLOCK_W ||
                (HIST_BINS!=8 && HIST_BINS!=16 && HIST_BINS!=32) ||
                BANKS < (BLOCK_H==64 ? 3:2))
        $fatal(1,"unsupported/unsafe Phase9 engine configuration");
    always @(posedge clk) if (rst_n) begin
        if (input_valid && fill_x==0 && fill_row==0 && !bank_free[fill_bank])
            $fatal(1,"PHASE9_BANK_OVERWRITE bank=%0d stripe=%0d",fill_bank,fill_stripe);
        if (input_valid && scan_clear && fill_bank==scan_bank)
            $fatal(1,"PHASE9_HIST_CLEAR_COLLISION");
        if (input_valid && read_request && fill_bank==replay_bank)
            $fatal(1,"PHASE9_STRIPE_READ_WRITE_COLLISION");
        if (scan_index>=HIST_ENTRIES && scan_state!=SCAN_IDLE)
            $fatal(1,"PHASE9_HIST_INDEX");
        if (fill_stripe>=BLOCK_ROWS || fill_row>=BLOCK_H || replay_row>=BLOCK_H)
            $fatal(1,"PHASE9_GEOMETRY");
    end
`endif
endmodule
`default_nettype wire
