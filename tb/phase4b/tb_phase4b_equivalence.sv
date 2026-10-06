`timescale 1ns / 1ps
module tb_phase4b_equivalence;
    localparam integer IMG_W=640, IMG_H=480, PIXELS=IMG_W*IMG_H;
    localparam integer EXTRA_LATENCY=2;
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
    wire ref_vs,ref_hs,ref_de,ref_bit;
    wire new_vs,new_hs,new_de,new_bit;
    canny_edge_detect_phase4_top u_reference (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(y_vs),
        .per_frame_href(y_hs),.per_frame_clken(y_de),.per_img_y(y),
        .post_frame_vsync(ref_vs),.post_frame_href(ref_hs),
        .post_frame_clken(ref_de),.post_img_bit(ref_bit));
    canny_edge_detect_phase4b_top u_new (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(y_vs),
        .per_frame_href(y_hs),.per_frame_clken(y_de),.per_img_y(y),
        .post_frame_vsync(new_vs),.post_frame_href(new_hs),
        .post_frame_clken(new_de),.post_img_bit(new_bit));
    video_to_pic #(.PIC_PATH("results/phase4b/outcom_phase4b.bmp"),
                   .START_FRAME(1),.IMG_HDISP(IMG_W),.IMG_VDISP(IMG_H))
        u_writer (.clk(clk),.rst_n(rst_n),.video_vsync(new_vs),
                  .video_hsync(new_hs),.video_de(new_de),
                  .video_data({24{new_bit}}));
    reg [3:0] ref_delay [0:EXTRA_LATENCY-1];
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0;i<EXTRA_LATENCY;i=i+1) ref_delay[i] <= 4'b0;
        end else begin
            ref_delay[0] <= {ref_vs,ref_hs,ref_de,ref_bit};
            for (i=1;i<EXTRA_LATENCY;i=i+1)
                ref_delay[i] <= ref_delay[i-1];
        end
    end
    integer frames=0,pixels=0,compared=0,mismatches=0,unknowns=0,edges=0;
    reg previous_vs=0;
    always @(posedge clk) begin
        if (!rst_n) begin
            frames=0;pixels=0;compared=0;mismatches=0;
            unknowns=0;edges=0;previous_vs=0;
        end else begin
            if ((^{new_vs,new_hs,new_de}) === 1'bx) begin
                unknowns=unknowns+1;
                $fatal(1,"PHASE4B_UNKNOWN_CONTROL time=%0t",$time);
            end
            if ({new_vs,new_hs,new_de} !== ref_delay[EXTRA_LATENCY-1][3:1])
                $fatal(1,"PHASE4B_CONTROL_MISMATCH time=%0t new=%b%b%b ref=%b",
                       $time,new_vs,new_hs,new_de,ref_delay[EXTRA_LATENCY-1][3:1]);
            if (new_de && new_hs) begin
                pixels=pixels+1;
                compared=compared+1;
                if ((^new_bit === 1'bx) ||
                    (^ref_delay[EXTRA_LATENCY-1][0] === 1'bx)) begin
                    unknowns=unknowns+1;
                    $fatal(1,"PHASE4B_UNKNOWN_PIXEL time=%0t",$time);
                end
                if (new_bit !== ref_delay[EXTRA_LATENCY-1][0]) begin
                    mismatches=mismatches+1;
                    $fatal(1,"PHASE4B_PIXEL_MISMATCH frame=%0d pixel=%0d time=%0t ref=%b new=%b",
                           frames,pixels,$time,ref_delay[EXTRA_LATENCY-1][0],new_bit);
                end
                if (new_bit) edges=edges+1;
            end
            if (previous_vs && !new_vs) begin
                $display("PHASE4B_FRAME index=%0d valid_pixels=%0d edge_pixels=%0d",
                         frames,pixels,edges);
                if (pixels!=PIXELS || edges==0 || edges==PIXELS)
                    $fatal(1,"PHASE4B_FRAME_FAIL index=%0d",frames);
                frames=frames+1;pixels=0;edges=0;
                if (frames==2) begin
                    $display("PHASE4B_EQUIVALENCE PASS frames=%0d pixels_compared=%0d mismatches=%0d unknowns=%0d latency_delta=%0d",
                             frames,compared,mismatches,unknowns,EXTRA_LATENCY);
                    $finish;
                end
            end
            previous_vs=new_vs;
        end
    end
endmodule
