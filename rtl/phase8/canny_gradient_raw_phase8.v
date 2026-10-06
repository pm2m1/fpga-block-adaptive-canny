`default_nettype none
// Phase 8 copy of Phase 6 Sobel/CORDIC path. Only threshold classification
// is removed: the registered output is {direction[3:0],magnitude[10:0]}.
module canny_gradient_raw_phase8 (
    input wire clk,rst_n,mediant_hs,mediant_vs,mediant_de,
    input wire [7:0] mediant_img,
    output reg gradient_hs,gradient_vs,gradient_de,
    output reg [14:0] gradient_path
);
    wire sobel_vsync,sobel_href,sobel_clken;
    wire [7:0] p11,p12,p13,p21,p22,p23,p31,p32,p33;
    matrix_generate_3x3_phase5b #(.DATA_WIDTH(8),.DATA_DEPTH(640)) u_matrix (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(mediant_vs),
        .per_frame_href(mediant_hs),.per_frame_clken(mediant_de),
        .per_img_y(mediant_img),.matrix_frame_vsync(sobel_vsync),
        .matrix_frame_href(sobel_href),.matrix_frame_clken(sobel_clken),
        .matrix_p11(p11),.matrix_p12(p12),.matrix_p13(p13),
        .matrix_p21(p21),.matrix_p22(p22),.matrix_p23(p23),
        .matrix_p31(p31),.matrix_p32(p32),.matrix_p33(p33));
    reg [9:0] gx_left,gx_right,gy_top,gy_bottom;
    reg [10:0] abs_gx,abs_gy;
    reg sign_gx,sign_gy;
    reg [1:0] vs_delay,hs_delay,de_delay;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx_left<=0;gx_right<=0;gy_top<=0;gy_bottom<=0;
            abs_gx<=0;abs_gy<=0;sign_gx<=1;sign_gy<=1;
            vs_delay<=0;hs_delay<=0;de_delay<=0;
        end else begin
            gx_left <= {2'b0,p11}+{1'b0,p21,1'b0}+{2'b0,p31};
            gx_right <= {2'b0,p13}+{1'b0,p23,1'b0}+{2'b0,p33};
            gy_top <= {2'b0,p11}+{1'b0,p12,1'b0}+{2'b0,p13};
            gy_bottom <= {2'b0,p31}+{1'b0,p32,1'b0}+{2'b0,p33};
            abs_gx <= gx_left>=gx_right ? gx_left-gx_right : gx_right-gx_left;
            abs_gy <= gy_top>=gy_bottom ? gy_top-gy_bottom : gy_bottom-gy_top;
            sign_gx <= gx_left>=gx_right;
            sign_gy <= gy_top>=gy_bottom;
            vs_delay <= {vs_delay[0],sobel_vsync};
            hs_delay <= {hs_delay[0],sobel_href};
            de_delay <= {de_delay[0],sobel_clken};
        end
    end
    wire [10:0] magnitude;
    wire [3:0] direction;
    wire cordic_vs,cordic_hs,cordic_de;
    cordic_gradient_phase4b #(.CORDIC_ITERATIONS(16)) u_cordic (
        .clk(clk),.rst_n(rst_n),.abs_gx(abs_gx),.abs_gy(abs_gy),
        .sign_gx(sign_gx),.sign_gy(sign_gy),
        .in_vsync(vs_delay[1]),.in_href(hs_delay[1]),
        .in_valid(de_delay[1]),.magnitude(magnitude),.direction(direction),
        .out_vsync(cordic_vs),.out_href(cordic_hs),.out_valid(cordic_de));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gradient_path<=0;gradient_vs<=0;gradient_hs<=0;gradient_de<=0;
        end else begin
            gradient_path<={direction,magnitude};
            gradient_vs<=cordic_vs;
            gradient_hs<=cordic_hs;
            gradient_de<=cordic_de;
        end
    end
endmodule
`default_nettype wire
