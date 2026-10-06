`timescale 1ns / 1ps
// Testbench-only hierarchical observer. Production Phase 4B RTL is untouched.
module tb_phase5b_trace;
    reg clk=0, rst_n=0, vs=0, hs=0, de=0;
    reg [7:0] gray=0;
    always #3 clk=~clk;
    wire out_vs,out_hs,out_de,out_bit;
    canny_edge_detect_phase5b_top u_dut (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),
        .per_frame_href(hs),.per_frame_clken(de),.per_img_y(gray),
        .post_frame_vsync(out_vs),.post_frame_href(out_hs),
        .post_frame_clken(out_de),.post_img_bit(out_bit));
    integer input_fd,trace_fd,fields,iv,ih,id,ip,cycle=0;
    integer pixels=0,frames=0,expected_pixels,expected_frames,stage_mode;
    reg previous_vs=0;
    reg [1023:0] input_path,trace_path;
    initial begin
`ifdef PHASE5B_ISOLATE_AB
        input_path="results/phase5b/isolate_ab.stream";
        trace_path="results/phase5b/isolate_ab.trace";
        expected_pixels=640*480;expected_frames=4;stage_mode=1;
`elsif PHASE5B_ISOLATE_CD
        input_path="results/phase5b/isolate_cd.stream";
        trace_path="results/phase5b/isolate_cd.trace";
        expected_pixels=640*480;expected_frames=4;stage_mode=1;
`elsif PHASE5B_LEAKAGE
        input_path="results/phase5b/leakage.stream";
        trace_path="results/phase5b/leakage.trace";
        expected_pixels=640*480;expected_frames=2;stage_mode=1;
`elsif PHASE5B_FULL
        input_path="results/phase5b/full.stream";
        trace_path="results/phase5b/full.trace";
        expected_pixels=640*480;expected_frames=2;stage_mode=1;
`else
        input_path="results/phase5b/small.stream";
        trace_path="results/phase5b/small.trace";
        expected_pixels=640*16;expected_frames=10;stage_mode=1;
`endif
        input_fd=$fopen(input_path,"r");
        trace_fd=$fopen(trace_path,"w");
        if (!input_fd || !trace_fd) $fatal(1,"Cannot open Phase 5 stream/trace");
        repeat (4) @(negedge clk);
        rst_n=1;
        while (!$feof(input_fd)) begin
            fields=$fscanf(input_fd,"%d %d %d %d\n",iv,ih,id,ip);
            if (fields==4) begin
                @(negedge clk);
                vs=iv[0];hs=ih[0];de=id[0];gray=ip[7:0];
                @(posedge clk);
                #1;
                if (stage_mode) begin
                    $fdisplay(trace_fd,
"%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                        cycle,iv,ih,id,ip,
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
                end else if (out_de && out_hs) begin
                    $fdisplay(trace_fd,"%0d %b",cycle,out_bit);
                end
                if (out_de && out_hs) begin
                    pixels=pixels+1;
                    if (out_bit !== 1'b0 && out_bit !== 1'b1)
                        $fatal(1,"PHASE5B_UNKNOWN_EDGE cycle=%0d",cycle);
                end
                if (previous_vs && !out_vs) begin
                    if (pixels != expected_pixels)
                        $fatal(1,"PHASE5B_PIXEL_COUNT frame=%0d got=%0d expected=%0d",
                               frames,pixels,expected_pixels);
                    $display("PHASE5B_FRAME frame=%0d valid_pixels=%0d",frames,pixels);
                    frames=frames+1;pixels=0;
                end
                previous_vs=out_vs;
                cycle=cycle+1;
            end
        end
        if (frames != expected_frames)
            $fatal(1,"PHASE5B_FRAME_COUNT got=%0d expected=%0d",frames,expected_frames);
        $fclose(input_fd);$fclose(trace_fd);
        $display("PHASE5B_RTL_TRACE_PASS frames=%0d cycles=%0d",frames,cycle);
        $finish;
    end
endmodule
