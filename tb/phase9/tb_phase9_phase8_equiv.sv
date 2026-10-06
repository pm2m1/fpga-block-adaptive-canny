`timescale 1ns/1ps
module tb_phase9_phase8_equiv;
    reg clk=0,rst_n=0,vs=0,hs=0,de=0;
    reg [7:0] gray=0;
    always #3 clk=~clk;
    wire a_vs,a_hs,a_de,a_edge,b_vs,b_hs,b_de,b_edge;
    canny_block_adaptive_phase8_top u_phase8 (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),.per_frame_href(hs),
        .per_frame_clken(de),.per_img_y(gray),.mode_i(1'b1),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(a_vs),.post_frame_href(a_hs),
        .post_frame_clken(a_de),.post_img_bit(a_edge));
    canny_block_adaptive_phase9_top #(.BLOCK_W(32),.BLOCK_H(32),.HIST_BINS(32)) u_phase9 (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),.per_frame_href(hs),
        .per_frame_clken(de),.per_img_y(gray),.mode_i(1'b1),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(b_vs),.post_frame_href(b_hs),
        .post_frame_clken(b_de),.post_img_bit(b_edge));
    integer fd,fields,iv,ih,id,ip,il,ihigh,pixels=0;
    initial begin
        fd=$fopen("results/phase6/fixed.stream","r");
        if (!fd) $fatal(1,"missing Phase 6 two-frame stream");
        repeat(4) @(negedge clk);rst_n=1;
        while (!$feof(fd)) begin
            fields=$fscanf(fd,"%d %d %d %d %d %d\n",iv,ih,id,ip,il,ihigh);
            if (fields==6) begin
                @(negedge clk);vs=iv[0];hs=ih[0];de=id[0];gray=ip[7:0];
            end
        end
        @(negedge clk);vs=0;hs=0;de=0;gray=0;
        repeat(25000) @(negedge clk);
        if (pixels!=614400) $fatal(1,"equivalence pixel count=%0d",pixels);
        $display("PHASE9_PHASE8_EQUIV_PASS pixels=%0d mismatches=0 unknowns=0",pixels);
        $fclose(fd);$finish;
    end
    always @(posedge clk) begin
        #1;
        if (rst_n) begin
            if ({a_vs,a_hs,a_de} !== {b_vs,b_hs,b_de})
                $fatal(1,"Phase8/9 control mismatch pixel=%0d",pixels);
            if (a_hs && a_de) begin
                if (a_edge !== b_edge)
                    $fatal(1,"Phase8/9 edge mismatch pixel=%0d old=%b new=%b",
                           pixels,a_edge,b_edge);
                pixels=pixels+1;
            end
        end
    end
endmodule
