`default_nettype none
// Phase 3: keep the validated Canny core untouched; move the existing
// Gaussian instance from the simulation harness into the synthesis hierarchy.
module canny_edge_detect_gaussian_top (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       per_frame_vsync,
    input  wire       per_frame_href,
    input  wire       per_frame_clken,
    input  wire [7:0] per_img_y,
    output wire       post_frame_vsync,
    output wire       post_frame_href,
    output wire       post_frame_clken,
    output wire       post_img_bit
);
    wire       gaussian_vsync;
    wire       gaussian_href;
    wire       gaussian_clken;
    wire [7:0] gaussian_y;

    image_gaussian_filter u_gaussian (
        .clk(clk), .rst_n(rst_n),
        .per_frame_vsync(per_frame_vsync),
        .per_frame_href(per_frame_href),
        .per_frame_clken(per_frame_clken),
        .per_img_gray(per_img_y),
        .post_frame_vsync(gaussian_vsync),
        .post_frame_href(gaussian_href),
        .post_frame_clken(gaussian_clken),
        .post_img_gray(gaussian_y)
    );

    canny_edge_detect_top u_canny_core (
        .clk(clk), .rst_n(rst_n),
        .per_frame_vsync(gaussian_vsync),
        .per_frame_href(gaussian_href),
        .per_frame_clken(gaussian_clken),
        .per_img_y(gaussian_y),
        .post_frame_vsync(post_frame_vsync),
        .post_frame_href(post_frame_href),
        .post_frame_clken(post_frame_clken),
        .post_img_bit(post_img_bit)
    );
endmodule
`default_nettype wire
