`default_nettype none
module canny_edge_detect_phase4_top (
    input wire clk,
    input wire rst_n,
    input wire per_frame_vsync,
    input wire per_frame_href,
    input wire per_frame_clken,
    input wire [7:0] per_img_y,
    output wire post_frame_vsync,
    output wire post_frame_href,
    output wire post_frame_clken,
    output wire post_img_bit
);
    wire gauss_vs,gauss_hs,gauss_de;
    wire [7:0] gauss_y;
    image_gaussian_filter u_gaussian (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(per_frame_vsync),
        .per_frame_href(per_frame_href),.per_frame_clken(per_frame_clken),
        .per_img_gray(per_img_y),.post_frame_vsync(gauss_vs),
        .post_frame_href(gauss_hs),.post_frame_clken(gauss_de),
        .post_img_gray(gauss_y));

    wire gradient_vs,gradient_hs,gradient_de;
    wire [16:0] gradient_path;
    canny_get_gradient_phase4 u_gradient (
        .clk(clk),.rst_n(rst_n),.mediant_vs(gauss_vs),
        .mediant_hs(gauss_hs),.mediant_de(gauss_de),.mediant_img(gauss_y),
        .grandient_vs(gradient_vs),.grandient_hs(gradient_hs),
        .grandient_de(gradient_de),.gra_path(gradient_path));

    wire nms_vs,nms_hs,nms_de;
    wire [1:0] nms_class;
    canny_nonLocalMaxValue_phase4 u_nms (
        .clk(clk),.rst_n(rst_n),.grandient_vs(gradient_vs),
        .grandient_hs(gradient_hs),.grandient_de(gradient_de),
        .gra_path(gradient_path),.post_frame_vsync(nms_vs),
        .post_frame_href(nms_hs),.post_frame_clken(nms_de),.max_g(nms_class));

    canny_doubleThreshold #(.DATA_WIDTH(2),.DATA_DEPTH(640)) u_local_3x3 (
        .clk(clk),.rst_s(rst_n),.pre_frame_vsync(nms_vs),
        .pre_frame_href(nms_hs),.pre_frame_clken(nms_de),.max_g(nms_class),
        .post_frame_vsync(post_frame_vsync),.post_frame_href(post_frame_href),
        .post_frame_clken(post_frame_clken),.canny_out(post_img_bit));
endmodule
`default_nettype wire
