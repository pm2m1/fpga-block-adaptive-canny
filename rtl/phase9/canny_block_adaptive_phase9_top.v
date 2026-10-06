`default_nettype none
// Phase 9 varies only block geometry and histogram resolution. The verified
// Gaussian/Sobel/CORDIC/NMS and global local-promotion hardware are reused.
module canny_block_adaptive_phase9_top #(
    parameter integer BLOCK_W=32,
    parameter integer BLOCK_H=32,
    parameter integer HIST_BINS=32
) (
    input wire clk,rst_n,per_frame_vsync,per_frame_href,per_frame_clken,
    input wire [7:0] per_img_y,
    input wire mode_i,
    input wire [10:0] threshold_low_i,threshold_high_i,
    output wire post_frame_vsync,post_frame_href,post_frame_clken,post_img_bit
);
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
        .gradient_path(gradient_path),
        .post_frame_vsync(nms_vs),.post_frame_href(nms_hs),
        .post_frame_clken(nms_de),.suppressed_magnitude(nms_magnitude));
    wire class_vs,class_hs,class_de;
    wire [1:0] class_value;
    stripe_threshold_engine_phase9 #(.BLOCK_W(BLOCK_W),.BLOCK_H(BLOCK_H),
        .HIST_BINS(HIST_BINS)) u_stripe (
        .clk(clk),.rst_n(rst_n),.nms_vs(nms_vs),.nms_hs(nms_hs),
        .nms_de(nms_de),.nms_magnitude(nms_magnitude),
        .mode_active(mode_active),.fixed_low_active(threshold_low_active),
        .fixed_high_active(threshold_high_active),
        .class_vs(class_vs),.class_hs(class_hs),.class_de(class_de),
        .class_value(class_value));
    canny_doubleThreshold_phase5b #(.DATA_WIDTH(2),.DATA_DEPTH(640)) u_local_3x3 (
        .clk(clk),.rst_s(rst_n),.pre_frame_vsync(class_vs),
        .pre_frame_href(class_hs),.pre_frame_clken(class_de),
        .max_g(class_value),.post_frame_vsync(post_frame_vsync),
        .post_frame_href(post_frame_href),.post_frame_clken(post_frame_clken),
        .canny_out(post_img_bit));
endmodule
`default_nettype wire
