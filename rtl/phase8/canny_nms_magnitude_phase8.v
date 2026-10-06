`default_nettype none
// Same strict NMS test/window as Phase 6, but emit the 11-bit magnitude.
module canny_nms_magnitude_phase8 (
    input wire clk,rst_n,gradient_vs,gradient_hs,gradient_de,
    input wire [14:0] gradient_path,
    output reg post_frame_vsync,post_frame_href,post_frame_clken,
    output reg [10:0] suppressed_magnitude
);
    wire matrix_vs,matrix_hs,matrix_de;
    wire [14:0] p11,p12,p13,p21,p22,p23,p31,p32,p33;
    matrix_generate_3x3_phase5b #(.DATA_WIDTH(15),.DATA_DEPTH(640)) u_matrix (
        .clk(clk),.rst_n(rst_n),
        .per_frame_vsync(gradient_vs),.per_frame_href(gradient_hs),
        .per_frame_clken(gradient_de),.per_img_y(gradient_path),
        .matrix_frame_vsync(matrix_vs),.matrix_frame_href(matrix_hs),
        .matrix_frame_clken(matrix_de),
        .matrix_p11(p11),.matrix_p12(p12),.matrix_p13(p13),
        .matrix_p21(p21),.matrix_p22(p22),.matrix_p23(p23),
        .matrix_p31(p31),.matrix_p32(p32),.matrix_p33(p33));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            suppressed_magnitude<=0;
            post_frame_vsync<=0;post_frame_href<=0;post_frame_clken<=0;
        end else begin
            case (p22[14:11])
                4'b0001: suppressed_magnitude <= (p22[10:0]>p21[10:0] && p22[10:0]>p23[10:0]) ? p22[10:0] : 11'd0;
                4'b0010: suppressed_magnitude <= (p22[10:0]>p13[10:0] && p22[10:0]>p31[10:0]) ? p22[10:0] : 11'd0;
                4'b0100: suppressed_magnitude <= (p22[10:0]>p12[10:0] && p22[10:0]>p32[10:0]) ? p22[10:0] : 11'd0;
                4'b1000: suppressed_magnitude <= (p22[10:0]>p11[10:0] && p22[10:0]>p33[10:0]) ? p22[10:0] : 11'd0;
                default: suppressed_magnitude <= 11'd0;
            endcase
            post_frame_vsync<=matrix_vs;
            post_frame_href<=matrix_hs;
            post_frame_clken<=matrix_de;
        end
    end
endmodule
`default_nettype wire
