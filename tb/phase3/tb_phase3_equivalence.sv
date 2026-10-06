`timescale 1ns / 1ps
module tb_phase3_equivalence;
    localparam integer IMG_W = 640;
    localparam integer IMG_H = 480;
    localparam integer PIXELS = IMG_W * IMG_H;
    reg clk = 0;
    reg rst_n = 0;
    always #3 clk = ~clk;
    initial #120 rst_n = 1;

    wire in_vs, in_hs, in_de;
    wire [23:0] rgb;
    sim_cmos #(.PIC_PATH("images/monkey.bmp"), .IMG_HDISP(IMG_W), .IMG_VDISP(IMG_H))
        u_source (.clk(clk), .rst_n(rst_n), .CMOS_VSYNC(in_vs),
                  .CMOS_HREF(in_hs), .CMOS_CLKEN(in_de), .CMOS_DATA(rgb),
                  .X_POS(), .Y_POS());

    wire y_vs, y_hs, y_de;
    wire [7:0] y, cb, cr;
    VIP_RGB888_YCbCr444 u_rgb_to_y (
        .clk(clk), .rst_n(rst_n), .per_frame_vsync(in_vs),
        .per_frame_href(in_hs), .per_frame_clken(in_de),
        .per_img_red(rgb[23:16]), .per_img_green(rgb[15:8]),
        .per_img_blue(rgb[7:0]), .post_frame_vsync(y_vs),
        .post_frame_href(y_hs), .post_frame_clken(y_de),
        .post_img_Y(y), .post_img_Cb(cb), .post_img_Cr(cr));

    // Reference: the exact Phase-1 placement of Gaussian before baseline Canny.
    wire g_vs, g_hs, g_de;
    wire [7:0] g_y;
    image_gaussian_filter u_reference_gaussian (
        .clk(clk), .rst_n(rst_n), .per_frame_vsync(y_vs),
        .per_frame_href(y_hs), .per_frame_clken(y_de), .per_img_gray(y),
        .post_frame_vsync(g_vs), .post_frame_href(g_hs),
        .post_frame_clken(g_de), .post_img_gray(g_y));
    wire ref_vs, ref_hs, ref_de, ref_bit;
    canny_edge_detect_top u_reference_canny (
        .clk(clk), .rst_n(rst_n), .per_frame_vsync(g_vs),
        .per_frame_href(g_hs), .per_frame_clken(g_de), .per_img_y(g_y),
        .post_frame_vsync(ref_vs), .post_frame_href(ref_hs),
        .post_frame_clken(ref_de), .post_img_bit(ref_bit));

    // New: same grayscale Y enters the Gaussian-containing synthesis top.
    wire dut_vs, dut_hs, dut_de, dut_bit;
    canny_edge_detect_gaussian_top u_dut (
        .clk(clk), .rst_n(rst_n), .per_frame_vsync(y_vs),
        .per_frame_href(y_hs), .per_frame_clken(y_de), .per_img_y(y),
        .post_frame_vsync(dut_vs), .post_frame_href(dut_hs),
        .post_frame_clken(dut_de), .post_img_bit(dut_bit));

    video_to_pic #(.PIC_PATH("results/phase3/outcom.bmp"),
                   .START_FRAME(1), .IMG_HDISP(IMG_W), .IMG_VDISP(IMG_H))
        u_writer (.clk(clk), .rst_n(rst_n), .video_vsync(dut_vs),
                  .video_hsync(dut_hs), .video_de(dut_de),
                  .video_data({24{dut_bit}}));

    integer frame_idx = 0;
    integer frame_pixels = 0;
    integer frame_matches = 0;
    integer frame_mismatches = 0;
    integer frame_unknowns = 0;
    integer total_compared = 0;
    integer total_mismatches = 0;
    integer first_x = -1, first_y = -1;
    reg first_ref = 0, first_dut = 0;
    time first_time = 0;
    reg previous_vs = 0;

    // Read the already-registered outputs at each rising clock, as Phase 1 did.
    always @(posedge clk) begin
        if (!rst_n) begin
            frame_idx = 0;
            frame_pixels = 0;
            frame_matches = 0;
            frame_mismatches = 0;
            frame_unknowns = 0;
            total_compared = 0;
            total_mismatches = 0;
            first_x = -1;
            first_y = -1;
            previous_vs = 0;
        end else begin
            if ((^{ref_vs,ref_hs,ref_de,dut_vs,dut_hs,dut_de}) === 1'bx)
                $fatal(1, "PHASE3_UNKNOWN_CONTROL time=%0t", $time);
            if ({ref_vs,ref_hs,ref_de} !== {dut_vs,dut_hs,dut_de})
                $fatal(1, "PHASE3_CONTROL_MISMATCH time=%0t ref=%b%b%b dut=%b%b%b",
                       $time, ref_vs, ref_hs, ref_de, dut_vs, dut_hs, dut_de);
            if (ref_de && ref_hs) begin
                if ((^ref_bit === 1'bx) || (^dut_bit === 1'bx))
                    frame_unknowns = frame_unknowns + 1;
                if (ref_bit === dut_bit && (^ref_bit !== 1'bx))
                    frame_matches = frame_matches + 1;
                else begin
                    frame_mismatches = frame_mismatches + 1;
                    if (first_x < 0) begin
                        first_x = frame_pixels % IMG_W;
                        first_y = frame_pixels / IMG_W;
                        first_time = $time;
                        first_ref = ref_bit;
                        first_dut = dut_bit;
                    end
                end
                frame_pixels = frame_pixels + 1;
                total_compared = total_compared + 1;
            end
            if (previous_vs && !ref_vs) begin
                $display("PHASE3_FRAME index=%0d pixels_compared=%0d pixels_matching=%0d pixels_mismatching=%0d unknown_pixels=%0d first_x=%0d first_y=%0d first_time=%0t first_ref=%b first_phase3=%b",
                         frame_idx, frame_pixels, frame_matches,
                         frame_mismatches, frame_unknowns, first_x, first_y,
                         first_time, first_ref, first_dut);
                total_mismatches = total_mismatches + frame_mismatches;
                if (frame_pixels != PIXELS || frame_mismatches != 0 || frame_unknowns != 0)
                    $fatal(1, "PHASE3_FRAME_FAIL index=%0d", frame_idx);
                frame_idx = frame_idx + 1;
                frame_pixels = 0;
                frame_matches = 0;
                frame_mismatches = 0;
                frame_unknowns = 0;
                first_x = -1;
                first_y = -1;
            end
            previous_vs = ref_vs;
        end
    end
endmodule
