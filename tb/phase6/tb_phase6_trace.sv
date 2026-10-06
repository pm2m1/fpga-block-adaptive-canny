`timescale 1ns / 1ps
// Testbench-only stage observer. Production top retains only streaming ports.
module tb_phase6_trace;
    reg clk=0, rst_n=0, vs=0, hs=0, de=0;
    reg [7:0] gray=0;
    reg [10:0] low_i=50, high_i=100;
    always #3 clk=~clk;
    wire out_vs,out_hs,out_de,out_bit;
    canny_edge_detect_phase6_top u_dut (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),
        .per_frame_href(hs),.per_frame_clken(de),.per_img_y(gray),
        .threshold_low_i(low_i),.threshold_high_i(high_i),
        .post_frame_vsync(out_vs),.post_frame_href(out_hs),
        .post_frame_clken(out_de),.post_img_bit(out_bit));
`ifdef PHASE6_FIXED
    wire ref_vs,ref_hs,ref_de,ref_bit;
    canny_edge_detect_phase5b_top u_reference (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),
        .per_frame_href(hs),.per_frame_clken(de),.per_img_y(gray),
        .post_frame_vsync(ref_vs),.post_frame_href(ref_hs),
        .post_frame_clken(ref_de),.post_img_bit(ref_bit));
`endif
    integer input_fd,trace_fd,fields,iv,ih,id,ip,il,ihigh,cycle=0;
    integer pixels=0,frames=0,expected_frames,reference_pixels=0;
    reg previous_vs=0,previous_input_vs=0;
    reg [1023:0] input_path,trace_path;
    initial begin
`ifdef PHASE6_FIXED
        input_path="results/phase6/fixed.stream";
        trace_path="results/phase6/fixed.trace";
        expected_frames=2;
`elsif PHASE6_ATOMIC
        input_path="results/phase6/atomic.stream";
        trace_path="results/phase6/atomic.trace";
        expected_frames=2;
`elsif PHASE6_MULTI
        input_path="results/phase6/multi.stream";
        trace_path="results/phase6/multi.trace";
        expected_frames=6;
`elsif PHASE6_TREND
        input_path="results/phase6/trend.stream";
        trace_path="results/phase6/trend.trace";
        expected_frames=4;
`elsif PHASE6_ISOLATE
        input_path="results/phase6/isolate.stream";
        trace_path="results/phase6/isolate.trace";
        expected_frames=4;
`else
        $fatal(1,"Missing Phase 6 suite define");
`endif
        input_fd=$fopen(input_path,"r");
        trace_fd=$fopen(trace_path,"w");
        if (!input_fd || !trace_fd) $fatal(1,"Cannot open Phase 6 stream/trace");
        repeat (4) @(negedge clk);
        rst_n=1;
        while (!$feof(input_fd)) begin
            fields=$fscanf(input_fd,"%d %d %d %d %d %d\n",iv,ih,id,ip,il,ihigh);
            if (fields==6) begin
                @(negedge clk);
                vs=iv[0];hs=ih[0];de=id[0];gray=ip[7:0];
                low_i=il[10:0];high_i=ihigh[10:0];
                if (iv && !previous_input_vs && il>=ihigh)
                    $fatal(1,"PHASE6_INVALID_THRESHOLDS low=%0d high=%0d",il,ihigh);
                previous_input_vs=iv[0];
                @(posedge clk);
                #1;
                $fdisplay(trace_fd,
"%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                    cycle,iv,ih,id,ip,il,ihigh,
                    u_dut.threshold_low_active,u_dut.threshold_high_active,
                    u_dut.gauss_vs,u_dut.gauss_hs,u_dut.gauss_de,u_dut.gauss_y,
                    u_dut.u_gradient.de_delay[1] & u_dut.u_gradient.hs_delay[1],
                    u_dut.u_gradient.abs_gx,u_dut.u_gradient.abs_gy,
                    u_dut.u_gradient.sign_gx,u_dut.u_gradient.sign_gy,
                    u_dut.u_gradient.cordic_de & u_dut.u_gradient.cordic_hs,
                    u_dut.u_gradient.magnitude,u_dut.u_gradient.direction,
                    u_dut.gradient_vs,u_dut.gradient_hs,u_dut.gradient_de,
                    u_dut.gradient_path,
                    u_dut.nms_vs,u_dut.nms_hs,u_dut.nms_de,u_dut.nms_class,
                    out_vs,out_hs,out_de,out_bit);
`ifdef PHASE6_FIXED
                if ({out_vs,out_hs,out_de} !== {ref_vs,ref_hs,ref_de})
                    $fatal(1,"PHASE6_REFERENCE_CONTROL_MISMATCH cycle=%0d",cycle);
                if (u_dut.gauss_de && u_dut.gauss_hs &&
                    u_dut.gauss_y !== u_reference.gauss_y)
                    $fatal(1,"PHASE6_REFERENCE_GAUSSIAN_MISMATCH cycle=%0d",cycle);
                if (u_dut.u_gradient.de_delay[1] && u_dut.u_gradient.hs_delay[1] &&
                    {u_dut.u_gradient.abs_gx,u_dut.u_gradient.abs_gy,
                     u_dut.u_gradient.sign_gx,u_dut.u_gradient.sign_gy} !==
                    {u_reference.u_gradient.abs_gx,u_reference.u_gradient.abs_gy,
                     u_reference.u_gradient.sign_gx,u_reference.u_gradient.sign_gy})
                    $fatal(1,"PHASE6_REFERENCE_SOBEL_MISMATCH cycle=%0d",cycle);
                if (u_dut.u_gradient.cordic_de && u_dut.u_gradient.cordic_hs &&
                    {u_dut.u_gradient.magnitude,u_dut.u_gradient.direction} !==
                    {u_reference.u_gradient.magnitude,u_reference.u_gradient.direction})
                    $fatal(1,"PHASE6_REFERENCE_CORDIC_MISMATCH cycle=%0d",cycle);
                if (u_dut.gradient_de && u_dut.gradient_hs &&
                    u_dut.gradient_path !== u_reference.gradient_path)
                    $fatal(1,"PHASE6_REFERENCE_THRESHOLD_MISMATCH cycle=%0d",cycle);
                if (u_dut.nms_de && u_dut.nms_hs &&
                    u_dut.nms_class !== u_reference.nms_class)
                    $fatal(1,"PHASE6_REFERENCE_NMS_MISMATCH cycle=%0d",cycle);
                if (out_de && out_hs) begin
                    reference_pixels=reference_pixels+1;
                    if (out_bit !== ref_bit)
                        $fatal(1,"PHASE6_REFERENCE_PIXEL_MISMATCH cycle=%0d",cycle);
                end
`endif
                if (out_de && out_hs) begin
                    pixels=pixels+1;
                    if (out_bit !== 1'b0 && out_bit !== 1'b1)
                        $fatal(1,"PHASE6_UNKNOWN_EDGE cycle=%0d",cycle);
                end
                if (previous_vs && !out_vs) begin
                    if (pixels != 307200)
                        $fatal(1,"PHASE6_PIXEL_COUNT frame=%0d got=%0d",frames,pixels);
                    $display("PHASE6_FRAME frame=%0d valid_pixels=%0d",frames,pixels);
                    frames=frames+1;pixels=0;
                end
                previous_vs=out_vs;
                cycle=cycle+1;
            end
        end
        if (frames != expected_frames)
            $fatal(1,"PHASE6_FRAME_COUNT got=%0d expected=%0d",frames,expected_frames);
`ifdef PHASE6_FIXED
        if (reference_pixels != 614400)
            $fatal(1,"PHASE6_REFERENCE_COUNT got=%0d",reference_pixels);
        $display("PHASE6_FIXED_REFERENCE_PASS frames=2 pixels_compared=%0d mismatches=0 unknowns=0",reference_pixels);
`endif
        $fclose(input_fd);$fclose(trace_fd);
        $display("PHASE6_RTL_TRACE_PASS frames=%0d cycles=%0d",frames,cycle);
        $finish;
    end
endmodule
