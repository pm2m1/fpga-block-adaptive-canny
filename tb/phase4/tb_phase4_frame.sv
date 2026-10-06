`timescale 1ns / 1ps
module tb_phase4_frame;
    localparam integer IMG_W=640, IMG_H=480, PIXELS=IMG_W*IMG_H;
    reg clk=0, rst_n=0;
    always #3 clk=~clk;
    initial #120 rst_n=1;
    wire src_vs,src_hs,src_de;
    wire [23:0] rgb;
    sim_cmos #(.PIC_PATH("images/monkey.bmp"),.IMG_HDISP(IMG_W),.IMG_VDISP(IMG_H))
        u_source (.clk(clk),.rst_n(rst_n),.CMOS_VSYNC(src_vs),
                  .CMOS_HREF(src_hs),.CMOS_CLKEN(src_de),.CMOS_DATA(rgb),
                  .X_POS(),.Y_POS());
    wire y_vs,y_hs,y_de;
    wire [7:0] y,cb,cr;
    VIP_RGB888_YCbCr444 u_rgb_to_y (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(src_vs),
        .per_frame_href(src_hs),.per_frame_clken(src_de),
        .per_img_red(rgb[23:16]),.per_img_green(rgb[15:8]),
        .per_img_blue(rgb[7:0]),.post_frame_vsync(y_vs),
        .post_frame_href(y_hs),.post_frame_clken(y_de),
        .post_img_Y(y),.post_img_Cb(cb),.post_img_Cr(cr));
    wire out_vs,out_hs,out_de,out_bit;
    canny_edge_detect_phase4_top u_dut (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(y_vs),
        .per_frame_href(y_hs),.per_frame_clken(y_de),.per_img_y(y),
        .post_frame_vsync(out_vs),.post_frame_href(out_hs),
        .post_frame_clken(out_de),.post_img_bit(out_bit));
    video_to_pic #(.PIC_PATH("results/phase4/outcom_phase4.bmp"),
                   .START_FRAME(1),.IMG_HDISP(IMG_W),.IMG_VDISP(IMG_H))
        u_writer (.clk(clk),.rst_n(rst_n),.video_vsync(out_vs),
                  .video_hsync(out_hs),.video_de(out_de),
                  .video_data({24{out_bit}}));
    integer frame_idx=0,pixels=0,unknowns=0,edges=0;
    reg previous_vs=0;
    always @(posedge clk) begin
        if (!rst_n) begin
            frame_idx=0;pixels=0;unknowns=0;edges=0;previous_vs=0;
        end else begin
            if ((^{out_vs,out_hs,out_de}) === 1'bx)
                $fatal(1,"PHASE4_UNKNOWN_CONTROL time=%0t",$time);
            if (out_de && out_hs) begin
                pixels=pixels+1;
                if (^out_bit === 1'bx) unknowns=unknowns+1;
                else if (out_bit) edges=edges+1;
            end
            if (previous_vs && !out_vs) begin
                $display("PHASE4_FRAME index=%0d valid_pixels=%0d unknown_pixels=%0d edge_pixels=%0d",
                         frame_idx,pixels,unknowns,edges);
                if (pixels!=PIXELS || unknowns!=0 || edges==0 || edges==PIXELS)
                    $fatal(1,"PHASE4_FRAME_FAIL index=%0d",frame_idx);
                frame_idx=frame_idx+1;pixels=0;unknowns=0;edges=0;
            end
            previous_vs=out_vs;
        end
    end
endmodule
