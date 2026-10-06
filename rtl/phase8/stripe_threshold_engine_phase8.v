`default_nettype none
// Two 32-row raster stripe banks. Input is one valid NMS magnitude per pixel.
// Histogram scan is 20*32=640 clocks, then 640-clock synchronous clear; replay
// reads one pixel/clock with one blank clock after each output line. The tested
// source protocol supplies 24 blank clocks per input line. This module has NO
// backpressure: assertions fail if that cadence cannot keep both banks safe.
module stripe_threshold_engine_phase8 (
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
    reg [10:0] stripe0 [0:20479];
    reg [10:0] stripe1 [0:20479];
    reg [10:0] read_data0,read_data1;
    reg fill_bank;
    reg [9:0] fill_x;
    reg [4:0] fill_row;
    reg [3:0] fill_stripe;
    reg nms_vs_d;
    reg bank_free [0:1];
    reg bank_complete [0:1];
    reg bank_ready [0:1];
    reg bank_cleared [0:1];
    reg bank_replayed [0:1];
    reg bank_mode [0:1];
    reg [10:0] bank_fixed_low [0:1];
    reg [10:0] bank_fixed_high [0:1];
    reg [3:0] bank_stripe [0:1];
    reg [10:0] block_low [0:1][0:19];
    reg [10:0] block_high [0:1][0:19];
    reg block_active [0:1][0:19];
    reg [4:0] block_bin [0:1][0:19];

    wire input_valid=nms_hs && nms_de;
    wire [14:0] fill_addr=({fill_row,9'b0}+{fill_row,7'b0})+{5'b0,fill_x};
    wire [4:0] fill_block=fill_x[9:5];
    reg [1:0] scan_state;
    reg scan_bank;
    reg [9:0] scan_index;
    reg [10:0] cumulative;
    reg selected;
    reg scan_valid_pipe,scan_first_pipe;
    reg [4:0] scan_block_pipe,scan_bin_pipe;
    reg [10:0] scan_count_pipe,scan_nonzero_pipe;
    wire [4:0] scan_bin=5'd31-scan_index[4:0];
    wire [9:0] scan_hist_addr={scan_index[9:5],scan_bin};
    wire scan_clear=scan_state==SCAN_CLEAR;
    wire [10:0] hist_count0,hist_count1,nonzero0,nonzero1;
    histogram_unit_phase8 u_hist0 (
        .clk(clk),.update_en(input_valid && !fill_bank),
        .update_block(fill_block),.update_magnitude(nms_magnitude),
        .clear_en(scan_clear && !scan_bank),.clear_addr(scan_index),
        .scan_addr(scan_hist_addr),.scan_count(hist_count0),
        .scan_nonzero(nonzero0));
    histogram_unit_phase8 u_hist1 (
        .clk(clk),.update_en(input_valid && fill_bank),
        .update_block(fill_block),.update_magnitude(nms_magnitude),
        .clear_en(scan_clear && scan_bank),.clear_addr(scan_index),
        .scan_addr(scan_hist_addr),.scan_count(hist_count1),
        .scan_nonzero(nonzero1));
    wire [10:0] scan_hist_count=scan_bank ? hist_count1:hist_count0;
    wire [10:0] scan_nonzero=scan_bank ? nonzero1:nonzero0;
    wire [10:0] cumulative_input=scan_first_pipe ? 11'd0:cumulative;
    wire [10:0] cumulative_next,step_high,step_low;
    wire crossing;
    adaptive_threshold_step_phase8 u_step (
        .cumulative_i(cumulative_input),.bin_count_i(scan_count_pipe),
        .nonzero_i(scan_nonzero_pipe),.bin_i(scan_bin_pipe),
        .cumulative_o(cumulative_next),.crossing_o(crossing),
        .high_o(step_high),.low_o(step_low));

    reg replay_active,replay_bank,replay_expect_bank,replay_gap;
    reg [9:0] replay_x;
    reg [4:0] replay_row;
    wire read_request=replay_active && !replay_gap;
    wire [14:0] read_addr=({replay_row,9'b0}+{replay_row,7'b0})+{5'b0,replay_x};
    reg read_valid,read_bank_d,read_first_frame,read_final_frame,read_last_stripe;
    reg [4:0] read_block;
    reg end_frame_pending;
    wire [10:0] read_magnitude=read_bank_d ? read_data1:read_data0;
    wire [10:0] chosen_low=bank_mode[read_bank_d] ?
        block_low[read_bank_d][read_block]:bank_fixed_low[read_bank_d];
    wire [10:0] chosen_high=bank_mode[read_bank_d] ?
        block_high[read_bank_d][read_block]:bank_fixed_high[read_bank_d];
    wire chosen_active=bank_mode[read_bank_d] ?
        block_active[read_bank_d][read_block]:1'b1;

    always @(posedge clk) begin
        if (input_valid && !fill_bank) stripe0[fill_addr]<=nms_magnitude;
        if (input_valid && fill_bank) stripe1[fill_addr]<=nms_magnitude;
        if (read_request && !replay_bank) read_data0<=stripe0[read_addr];
        if (read_request && replay_bank) read_data1<=stripe1[read_addr];
    end

    integer i,j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fill_bank<=0;fill_x<=0;fill_row<=0;fill_stripe<=0;
            nms_vs_d<=0;
            scan_state<=SCAN_IDLE;scan_bank<=0;scan_index<=0;
            cumulative<=0;selected<=0;
            scan_valid_pipe<=0;scan_first_pipe<=0;
            scan_block_pipe<=0;scan_bin_pipe<=0;
            scan_count_pipe<=0;scan_nonzero_pipe<=0;
            replay_active<=0;replay_bank<=0;replay_expect_bank<=0;
            replay_gap<=0;replay_x<=0;replay_row<=0;
            read_valid<=0;read_bank_d<=0;read_first_frame<=0;
            read_final_frame<=0;read_last_stripe<=0;read_block<=0;
            class_vs<=0;class_hs<=0;class_de<=0;class_value<=0;
            end_frame_pending<=0;
            for (i=0;i<2;i=i+1) begin
                bank_free[i]<=1;bank_complete[i]<=0;bank_ready[i]<=0;
                bank_cleared[i]<=1;bank_replayed[i]<=1;
                bank_mode[i]<=0;bank_fixed_low[i]<=11'd50;
                bank_fixed_high[i]<=11'd100;bank_stripe[i]<=0;
                for (j=0;j<20;j=j+1) begin
                    block_low[i][j]<=0;block_high[i][j]<=0;
                    block_active[i][j]<=0;block_bin[i][j]<=0;
                end
            end
        end else begin
            nms_vs_d<=nms_vs;
            if (nms_vs && !nms_vs_d) fill_stripe<=0;
            if (input_valid) begin
                if (fill_x==0 && fill_row==0) begin
                    bank_free[fill_bank]<=0;
                    bank_cleared[fill_bank]<=0;
                    bank_replayed[fill_bank]<=0;
                    bank_mode[fill_bank]<=mode_active;
                    bank_fixed_low[fill_bank]<=fixed_low_active;
                    bank_fixed_high[fill_bank]<=fixed_high_active;
                    bank_stripe[fill_bank]<=nms_vs && !nms_vs_d ? 4'd0:fill_stripe;
                end
                if (fill_x==10'd639) begin
                    fill_x<=0;
                    if (fill_row==5'd31) begin
                        fill_row<=0;
                        fill_stripe<=fill_stripe==4'd14 ? 4'd0:fill_stripe+4'd1;
                        bank_complete[fill_bank]<=1;
                        fill_bank<=!fill_bank;
                    end else fill_row<=fill_row+5'd1;
                end else fill_x<=fill_x+10'd1;
            end

            scan_valid_pipe<=scan_state==SCAN_BINS;
            if (scan_state==SCAN_BINS) begin
                scan_count_pipe<=scan_hist_count;
                scan_nonzero_pipe<=scan_nonzero;
                scan_block_pipe<=scan_index[9:5];
                scan_bin_pipe<=scan_bin;
                scan_first_pipe<=scan_index[4:0]==5'd0;
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
                SCAN_IDLE: begin
                    if (bank_complete[0] || bank_complete[1]) begin
                        scan_bank<=bank_complete[0] ? 1'b0:1'b1;
                        bank_complete[bank_complete[0] ? 1'b0:1'b1]<=0;
                        scan_index<=0;cumulative<=0;selected<=0;
                        scan_state<=SCAN_BINS;
                    end
                end
                SCAN_BINS: begin
                    if (scan_index==10'd639) begin
                        scan_index<=0;scan_state<=SCAN_DRAIN;
                    end else scan_index<=scan_index+10'd1;
                end
                SCAN_DRAIN: begin
                    scan_index<=0;scan_state<=SCAN_CLEAR;
                    bank_ready[scan_bank]<=1;
                end
                SCAN_CLEAR: begin
                    if (scan_index==10'd639) begin
                        scan_index<=0;scan_state<=SCAN_IDLE;
                        bank_cleared[scan_bank]<=1;
                    end else scan_index<=scan_index+10'd1;
                end
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
                    if (replay_row==5'd31) begin
                        replay_row<=0;replay_active<=0;
                        replay_expect_bank<=!replay_expect_bank;
                    end else begin
                        replay_row<=replay_row+5'd1;
                        replay_gap<=1;
                    end
                end else replay_x<=replay_x+10'd1;
            end

            read_valid<=read_request;
            if (read_request) begin
                read_bank_d<=replay_bank;
                read_block<=replay_x[9:5];
                read_first_frame<=bank_stripe[replay_bank]==4'd0 &&
                                  replay_row==0 && replay_x==0;
                read_final_frame<=bank_stripe[replay_bank]==4'd14 &&
                                  replay_row==5'd31 && replay_x==10'd639;
                read_last_stripe<=replay_row==5'd31 && replay_x==10'd639;
            end else begin
                read_first_frame<=0;read_final_frame<=0;read_last_stripe<=0;
            end
            class_hs<=read_valid;
            class_de<=read_valid;
            if (read_valid)
                class_value <= !chosen_active ? 2'd0 :
                    read_magnitude>chosen_high ? 2'd2 :
                    read_magnitude>chosen_low ? 2'd1 : 2'd0;
            else class_value<=0;
            if (read_valid && read_first_frame) class_vs<=1;
            else if (end_frame_pending) class_vs<=0;
            end_frame_pending<=read_valid && read_final_frame;
            if (read_valid && read_last_stripe)
                bank_replayed[read_bank_d]<=1;
            if (bank_cleared[0] && bank_replayed[0] &&
                !(input_valid && fill_bank==1'b0 && fill_x==0 && fill_row==0))
                bank_free[0]<=1;
            if (bank_cleared[1] && bank_replayed[1] &&
                !(input_valid && fill_bank==1'b1 && fill_x==0 && fill_row==0))
                bank_free[1]<=1;
        end
    end
`ifndef SYNTHESIS
    always @(posedge clk) if (rst_n) begin
        if (input_valid && fill_x==0 && fill_row==0 && !bank_free[fill_bank])
            $fatal(1,"PHASE8_BANK_OVERWRITE bank=%0d stripe=%0d",fill_bank,fill_stripe);
        if (input_valid && scan_clear && fill_bank==scan_bank)
            $fatal(1,"PHASE8_HIST_CLEAR_COLLISION bank=%0d",fill_bank);
        if (input_valid && read_request && fill_bank==replay_bank)
            $fatal(1,"PHASE8_STRIPE_READ_WRITE_COLLISION bank=%0d",fill_bank);
        if (scan_index[9:5]>=5'd20 && scan_state!=SCAN_IDLE)
            $fatal(1,"PHASE8_INVALID_BLOCK_INDEX");
        // Five-bit row counters cannot represent 32; their wrap condition is
        // checked by the end-of-row logic. Stripe ID must remain 0..14.
        if (fill_stripe>4'd14)
            $fatal(1,"PHASE8_INVALID_GEOMETRY");
    end
`endif
endmodule
`default_nettype wire
