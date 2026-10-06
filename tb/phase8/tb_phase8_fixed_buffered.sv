`timescale 1ns/1ps
module tb_phase8_fixed_buffered;
    reg clk=0,rst_n=0,vs=0,hs=0,de=0;
    reg [7:0] gray=0;
    always #3 clk=~clk;
    wire out_vs,out_hs,out_de,out_bit;
    canny_block_adaptive_phase8_top u_dut (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),.per_frame_href(hs),
        .per_frame_clken(de),.per_img_y(gray),.mode_i(1'b0),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(out_vs),.post_frame_href(out_hs),
        .post_frame_clken(out_de),.post_img_bit(out_bit));
    reg [1:0] expected_class[0:614399];
    reg expected_edge[0:614399];
    integer fd,fields,iv,ih,id,ip,il,ihigh;
    integer input_pixels=0,nms_pixels=0,class_pixels=0,edge_pixels=0;
    integer frames=0,frame_pixels=0,stripes=0,cycles=0;
    reg old_out_vs=0;
    initial begin
        $readmemh("results/phase8/fixed_classes.mem",expected_class);
        $readmemh("results/phase8/fixed_edges.mem",expected_edge);
        fd=$fopen("results/phase6/fixed.stream","r");
        if (!fd) $fatal(1,"missing input stream");
        repeat (4) @(negedge clk);rst_n=1;
        while (!$feof(fd)) begin
            fields=$fscanf(fd,"%d %d %d %d %d %d\n",iv,ih,id,ip,il,ihigh);
            if (fields==6) begin
                @(negedge clk);vs=iv[0];hs=ih[0];de=id[0];gray=ip[7:0];
                if (ih && id) input_pixels=input_pixels+1;
            end
        end
        @(negedge clk);vs=0;hs=0;de=0;gray=0;
        repeat (25000) @(negedge clk);
        if (input_pixels!=614400 || nms_pixels!=614400 ||
            class_pixels!=614400 || edge_pixels!=614400 ||
            frames!=2 || stripes!=30)
            $fatal(1,"counts input=%0d nms=%0d class=%0d edge=%0d frames=%0d stripes=%0d",
                   input_pixels,nms_pixels,class_pixels,edge_pixels,frames,stripes);
        $display("PHASE8_BUFFERED_FIXED_PASS frames=%0d pixels=%0d blocks=%0d mismatches=0 unknowns=0",
                 frames,edge_pixels,stripes*20);
        $fclose(fd);$finish;
    end
    always @(posedge clk) begin
        #1;
        if (rst_n) begin
            cycles=cycles+1;
            if (u_dut.nms_hs && u_dut.nms_de) begin
                nms_pixels=nms_pixels+1;
                if (nms_pixels%20480==0) stripes=stripes+1;
            end
            if (u_dut.class_hs && u_dut.class_de) begin
                if (class_pixels>=614400) $fatal(1,"extra class");
                if (u_dut.class_value !== expected_class[class_pixels])
                    $fatal(1,"class mismatch pixel=%0d got=%0d expected=%0d",
                           class_pixels,u_dut.class_value,expected_class[class_pixels]);
                class_pixels=class_pixels+1;
            end
            if (out_hs && out_de) begin
                if (edge_pixels>=614400) $fatal(1,"extra edge");
                if (out_bit !== expected_edge[edge_pixels])
                    $fatal(1,"edge mismatch pixel=%0d got=%0d expected=%0d",
                           edge_pixels,out_bit,expected_edge[edge_pixels]);
                edge_pixels=edge_pixels+1;frame_pixels=frame_pixels+1;
            end
            if (old_out_vs && !out_vs) begin
                if (frame_pixels!=307200)
                    $fatal(1,"frame pixel count frame=%0d pixels=%0d",frames,frame_pixels);
                frames=frames+1;frame_pixels=0;
            end
            old_out_vs=out_vs;
        end
    end
endmodule
