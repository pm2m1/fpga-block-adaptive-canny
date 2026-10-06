`default_nettype none
// Identical strict-neighbor NMS rule to baseline, widened packed path 16->17.
module canny_nonLocalMaxValue_phase4 (
    input wire clk,
    input wire rst_n,
    input wire grandient_vs,
    input wire grandient_hs,
    input wire grandient_de,
    input wire [16:0] gra_path,
    output reg post_frame_vsync,
    output reg post_frame_href,
    output reg post_frame_clken,
    output reg [1:0] max_g
);
    wire matrix_vs,matrix_hs,matrix_de;
    wire [16:0] p11,p12,p13,p21,p22,p23,p31,p32,p33;
    matrix_generate_3x3 #(.DATA_WIDTH(17),.DATA_DEPTH(640)) u_matrix (
        .clk(clk),.rst_n(rst_n),
        .per_frame_vsync(grandient_vs),.per_frame_href(grandient_hs),
        .per_frame_clken(grandient_de),.per_img_y(gra_path),
        .matrix_frame_vsync(matrix_vs),.matrix_frame_href(matrix_hs),
        .matrix_frame_clken(matrix_de),
        .matrix_p11(p11),.matrix_p12(p12),.matrix_p13(p13),
        .matrix_p21(p21),.matrix_p22(p22),.matrix_p23(p23),
        .matrix_p31(p31),.matrix_p32(p32),.matrix_p33(p33));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_g<=0;
            post_frame_vsync<=0;post_frame_href<=0;post_frame_clken<=0;
        end else begin
            case (p22[14:11])
                4'b0001: max_g <= (p22[10:0]>p21[10:0] && p22[10:0]>p23[10:0]) ? p22[16:15] : 2'b00;
                4'b0010: max_g <= (p22[10:0]>p13[10:0] && p22[10:0]>p31[10:0]) ? p22[16:15] : 2'b00;
                4'b0100: max_g <= (p22[10:0]>p12[10:0] && p22[10:0]>p32[10:0]) ? p22[16:15] : 2'b00;
                4'b1000: max_g <= (p22[10:0]>p11[10:0] && p22[10:0]>p33[10:0]) ? p22[16:15] : 2'b00;
                default: max_g <= 2'b00;
            endcase
            post_frame_vsync<=matrix_vs;
            post_frame_href<=matrix_hs;
            post_frame_clken<=matrix_de;
        end
    end
endmodule
`default_nettype wire
