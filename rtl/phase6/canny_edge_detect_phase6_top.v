`default_nettype none
module canny_edge_detect_phase6_top (
    input wire clk,
    input wire rst_n,
    input wire per_frame_vsync,
    input wire per_frame_href,
    input wire per_frame_clken,
    input wire [7:0] per_img_y,
    input wire [10:0] threshold_low_i,
    input wire [10:0] threshold_high_i,
    output wire post_frame_vsync,
    output wire post_frame_href,
    output wire post_frame_clken,
    output wire post_img_bit
);
    reg frame_vsync_d;
    reg [10:0] threshold_low_active;
    reg [10:0] threshold_high_active;
    // Same VSYNC-rising frame-start convention as the Phase 5B windows.
    // A coincident first HREF pixel is included in the new frame.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_vsync_d <= 1'b0;
            threshold_low_active <= 11'd50;
            threshold_high_active <= 11'd100;
        end else begin
            frame_vsync_d <= per_frame_vsync;
            if (per_frame_vsync && !frame_vsync_d) begin
                threshold_low_active <= threshold_low_i;
                threshold_high_active <= threshold_high_i;
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
    wire [16:0] gradient_path;
    canny_get_gradient_phase6 u_gradient (
        .clk(clk),.rst_n(rst_n),.mediant_vs(gauss_vs),
        .mediant_hs(gauss_hs),.mediant_de(gauss_de),.mediant_img(gauss_y),
        .threshold_low_active(threshold_low_active),
        .threshold_high_active(threshold_high_active),
        .grandient_vs(gradient_vs),.grandient_hs(gradient_hs),
        .grandient_de(gradient_de),.gra_path(gradient_path));

    wire nms_vs,nms_hs,nms_de;
    wire [1:0] nms_class;
    canny_nonLocalMaxValue_phase5b u_nms (
        .clk(clk),.rst_n(rst_n),.grandient_vs(gradient_vs),
        .grandient_hs(gradient_hs),.grandient_de(gradient_de),
        .gra_path(gradient_path),.post_frame_vsync(nms_vs),
        .post_frame_href(nms_hs),.post_frame_clken(nms_de),.max_g(nms_class));

    canny_doubleThreshold_phase5b #(.DATA_WIDTH(2),.DATA_DEPTH(640)) u_local_3x3 (
        .clk(clk),.rst_s(rst_n),.pre_frame_vsync(nms_vs),
        .pre_frame_href(nms_hs),.pre_frame_clken(nms_de),.max_g(nms_class),
        .post_frame_vsync(post_frame_vsync),.post_frame_href(post_frame_href),
        .post_frame_clken(post_frame_clken),.canny_out(post_img_bit));
endmodule
`default_nettype wire

