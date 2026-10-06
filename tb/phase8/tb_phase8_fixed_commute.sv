`timescale 1ns/1ps
module tb_phase8_fixed_commute;
    reg clk=0,rst_n=0,vs=0,hs=0,de=0;
    reg [7:0] gray=0;
    always #3 clk=~clk;
    wire old_vs,old_hs,old_de,old_edge;
    wire new_vs,new_hs,new_de,new_edge,nms_vs,nms_hs,nms_de;
    wire [10:0] nms_magnitude;
    canny_edge_detect_phase6_top u_old (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),.per_frame_href(hs),
        .per_frame_clken(de),.per_img_y(gray),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(old_vs),.post_frame_href(old_hs),
        .post_frame_clken(old_de),.post_img_bit(old_edge));
    canny_postnms_fixed_phase8_top u_new (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),.per_frame_href(hs),
        .per_frame_clken(de),.per_img_y(gray),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(new_vs),.post_frame_href(new_hs),
        .post_frame_clken(new_de),.post_img_bit(new_edge),
        .nms_vs(nms_vs),.nms_hs(nms_hs),.nms_de(nms_de),
        .nms_magnitude(nms_magnitude));
    integer fd,fields,iv,ih,id,ip,il,ihigh;
    integer count=0,nms_count=0,frames=0,frame_pixels=0,cycle=0;
    reg previous_vs=0;
    initial begin
        fd=$fopen("results/phase6/fixed.stream","r");
        if (!fd) $fatal(1,"missing Phase 6 fixed stream");
        repeat (4) @(negedge clk);
        rst_n=1;
        while (!$feof(fd)) begin
            fields=$fscanf(fd,"%d %d %d %d %d %d\n",iv,ih,id,ip,il,ihigh);
            if (fields==6) begin
                @(negedge clk);
                vs=iv[0];hs=ih[0];de=id[0];gray=ip[7:0];
                @(posedge clk); #1;
                if ({old_vs,old_hs,old_de} !== {new_vs,new_hs,new_de})
                    $fatal(1,"control mismatch cycle=%0d",cycle);
                if ({u_old.nms_vs,u_old.nms_hs,u_old.nms_de} !== {nms_vs,nms_hs,nms_de})
                    $fatal(1,"NMS control mismatch cycle=%0d",cycle);
                if (nms_hs && nms_de) begin
                    nms_count=nms_count+1;
                    if (nms_magnitude === 11'bx)
                        $fatal(1,"unknown NMS magnitude cycle=%0d",cycle);
                    if (u_old.nms_class !==
                        (nms_magnitude>11'd100 ? 2'd2 :
                         nms_magnitude>11'd50 ? 2'd1 : 2'd0))
                        $fatal(1,"NMS/class mismatch cycle=%0d old=%0d mag=%0d",
                               cycle,u_old.nms_class,nms_magnitude);
                end
                if (new_hs && new_de) begin
                    count=count+1;frame_pixels=frame_pixels+1;
                    if (new_edge !== old_edge || new_edge === 1'bx)
                        $fatal(1,"edge mismatch cycle=%0d old=%b new=%b",cycle,old_edge,new_edge);
                end
                if (previous_vs && !new_vs) begin
                    if (frame_pixels != 307200)
                        $fatal(1,"frame pixel count frame=%0d count=%0d",frames,frame_pixels);
                    frames=frames+1;frame_pixels=0;
                end
                previous_vs=new_vs;
                cycle=cycle+1;
            end
        end
        if (frames!=2 || count!=614400 || nms_count!=614400)
            $fatal(1,"incomplete frames=%0d pixels=%0d nms=%0d",frames,count,nms_count);
        $display("PHASE8_FIXED_COMMUTE_PASS frames=2 nms=%0d pixels=%0d mismatches=0 unknowns=0",nms_count,count);
        $fclose(fd);$finish;
    end
endmodule
