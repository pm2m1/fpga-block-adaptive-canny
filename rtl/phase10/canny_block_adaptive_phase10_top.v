`default_nettype none
// One shared Canny front end and local-promotion output; only adaptive
// stripe state is replicated. Stripe s belongs to engine s % ENGINE_COUNT.
module canny_block_adaptive_phase10_top #(
    parameter integer ENGINE_COUNT=1
) (
    input wire clk,rst_n,per_frame_vsync,per_frame_href,per_frame_clken,
    input wire [7:0] per_img_y,
    input wire mode_i,
    input wire [10:0] threshold_low_i,threshold_high_i,
    output wire post_frame_vsync,post_frame_href,post_frame_clken,post_img_bit
);
    localparam integer STRIPE_PIXELS=20480;
    reg frame_vsync_d,mode_active;
    reg [10:0] threshold_low_active,threshold_high_active;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_vsync_d<=0;mode_active<=0;
            threshold_low_active<=11'd50;threshold_high_active<=11'd100;
        end else begin
            frame_vsync_d<=per_frame_vsync;
            if (per_frame_vsync && !frame_vsync_d) begin
                mode_active<=mode_i;
                threshold_low_active<=threshold_low_i;
                threshold_high_active<=threshold_high_i;
            end
        end
    end
    wire gauss_vs,gauss_hs,gauss_de;
    wire [7:0] gauss_y;
    image_gaussian_filter_phase5b u_gaussian (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(per_frame_vsync),
        .per_frame_href(per_frame_href),.per_frame_clken(per_frame_clken),
        .per_img_gray(per_img_y),.post_frame_vsync(gauss_vs),
        .post_frame_href(gauss_hs),.post_frame_clken(gauss_de),
        .post_img_gray(gauss_y));
    wire gradient_vs,gradient_hs,gradient_de;
    wire [14:0] gradient_path;
    canny_gradient_raw_phase8 u_gradient (
        .clk(clk),.rst_n(rst_n),.mediant_vs(gauss_vs),
        .mediant_hs(gauss_hs),.mediant_de(gauss_de),.mediant_img(gauss_y),
        .gradient_vs(gradient_vs),.gradient_hs(gradient_hs),
        .gradient_de(gradient_de),.gradient_path(gradient_path));
    wire nms_vs,nms_hs,nms_de;
    wire [10:0] nms_magnitude;
    canny_nms_magnitude_phase8 u_nms (
        .clk(clk),.rst_n(rst_n),.gradient_vs(gradient_vs),
        .gradient_hs(gradient_hs),.gradient_de(gradient_de),
        .gradient_path(gradient_path),.post_frame_vsync(nms_vs),
        .post_frame_href(nms_hs),.post_frame_clken(nms_de),
        .suppressed_magnitude(nms_magnitude));

    reg nms_vs_d;
    reg [3:0] input_stripe,merge_stripe;
    reg [14:0] input_pixel,merge_pixel;
    reg merge_active,merged_vs,end_frame_pending;
    reg [31:0] input_stripes_seen,output_stripes_seen;
    wire [ENGINE_COUNT-1:0] ready,pending,pending_last;
    wire [ENGINE_COUNT-1:0] stripe_complete_pulse,threshold_ready_pulse;
    wire [ENGINE_COUNT-1:0] e_vs,e_hs,e_de;
    wire [1:0] e_class [0:ENGINE_COUNT-1];
    wire [10:0] e_low [0:ENGINE_COUNT-1];
    wire [10:0] e_high [0:ENGINE_COUNT-1];
    wire [ENGINE_COUNT-1:0] e_active;
    wire [31:0] e_fill [0:ENGINE_COUNT-1];
    wire [31:0] e_scan [0:ENGINE_COUNT-1];
    wire [31:0] e_replay [0:ENGINE_COUNT-1];
    wire [31:0] e_busy [0:ENGINE_COUNT-1];
    wire [ENGINE_COUNT-1:0] grant;
    wire [2:0] input_owner=input_stripe % ENGINE_COUNT;
    wire [2:0] merge_owner=merge_stripe % ENGINE_COUNT;
    wire selected_de=merge_active && e_de[merge_owner];
    wire selected_pending=merge_active && pending[merge_owner];
    wire selected_pending_last=merge_active && pending_last[merge_owner];
    wire [1:0] class_value=merge_active ? e_class[merge_owner]:2'd0;
    wire class_hs=selected_de;
    wire class_de=selected_de;
    wire class_vs=merged_vs;
    wire [10:0] class_low=e_low[merge_owner];
    wire [10:0] class_high=e_high[merge_owner];
    wire class_active=e_active[merge_owner];

    genvar engine_id;
    generate for (engine_id=0;engine_id<ENGINE_COUNT;engine_id=engine_id+1) begin:g_engine
        wire this_input=nms_hs && nms_de && input_owner==engine_id;
        assign grant[engine_id]=!merge_active && merge_owner==engine_id && ready[engine_id];
        block_adaptive_engine_phase10 #(.BLOCK_W(32),.BLOCK_H(32),
            .HIST_BINS(32),.BANKS(2)) u_engine (
            .clk(clk),.rst_n(rst_n),.nms_vs(nms_vs),
            .nms_hs(this_input),.nms_de(this_input),
            .nms_magnitude(nms_magnitude),.mode_active(mode_active),
            .fixed_low_active(threshold_low_active),
            .fixed_high_active(threshold_high_active),
            .replay_grant_i(grant[engine_id]),.stripe_ready_o(ready[engine_id]),
            .stripe_complete_pulse_o(stripe_complete_pulse[engine_id]),
            .threshold_ready_pulse_o(threshold_ready_pulse[engine_id]),
            .class_pending_o(pending[engine_id]),
            .class_pending_last_o(pending_last[engine_id]),
            .class_vs(e_vs[engine_id]),.class_hs(e_hs[engine_id]),
            .class_de(e_de[engine_id]),.class_value(e_class[engine_id]),
            .class_low_o(e_low[engine_id]),.class_high_o(e_high[engine_id]),
            .class_active_o(e_active[engine_id]),
            .fill_cycles_o(e_fill[engine_id]),.scan_cycles_o(e_scan[engine_id]),
            .replay_cycles_o(e_replay[engine_id]),.active_cycles_o(e_busy[engine_id]));
    end endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nms_vs_d<=0;input_stripe<=0;input_pixel<=0;
            merge_stripe<=0;merge_pixel<=0;merge_active<=0;
            merged_vs<=0;end_frame_pending<=0;
            input_stripes_seen<=0;output_stripes_seen<=0;
        end else begin
            nms_vs_d<=nms_vs;
            if (nms_vs && !nms_vs_d) input_stripe<=0;
            if (nms_hs && nms_de) begin
                if (input_pixel==STRIPE_PIXELS-1) begin
                    input_pixel<=0;
                    input_stripe<=input_stripe==14 ? 0:input_stripe+1'b1;
                    input_stripes_seen<=input_stripes_seen+1'b1;
                end else input_pixel<=input_pixel+1'b1;
            end
            if (!merge_active && grant[merge_owner]) merge_active<=1;
            if (selected_pending && merge_stripe==0 && merge_pixel==0)
                merged_vs<=1;
            if (selected_pending_last && merge_stripe==14)
                end_frame_pending<=1;
            if (end_frame_pending) begin
                merged_vs<=0;end_frame_pending<=0;
            end
            if (selected_de) begin
                if (merge_pixel==STRIPE_PIXELS-1) begin
                    merge_pixel<=0;merge_active<=0;
                    merge_stripe<=merge_stripe==14 ? 0:merge_stripe+1'b1;
                    output_stripes_seen<=output_stripes_seen+1'b1;
                end else merge_pixel<=merge_pixel+1'b1;
            end
        end
    end
    canny_doubleThreshold_phase5b #(.DATA_WIDTH(2),.DATA_DEPTH(640)) u_local_3x3 (
        .clk(clk),.rst_s(rst_n),.pre_frame_vsync(class_vs),
        .pre_frame_href(class_hs),.pre_frame_clken(class_de),
        .max_g(class_value),.post_frame_vsync(post_frame_vsync),
        .post_frame_href(post_frame_href),.post_frame_clken(post_frame_clken),
        .canny_out(post_img_bit));
`ifndef SYNTHESIS
    initial if (ENGINE_COUNT!=1 && ENGINE_COUNT!=2 && ENGINE_COUNT!=4)
        $fatal(1,"unsupported ENGINE_COUNT");
    always @(posedge clk) if (rst_n) begin
        if ((grant & (grant-1'b1))!=0) $fatal(1,"duplicate replay grant");
        if (selected_de && merge_pixel>=STRIPE_PIXELS) $fatal(1,"merge coordinate");
        if (nms_hs && nms_de && input_pixel>=STRIPE_PIXELS)
            $fatal(1,"input coordinate");
        if (output_stripes_seen>input_stripes_seen)
            $fatal(1,"replay ahead of collected stripe");
    end
`endif
endmodule
`default_nettype wire
