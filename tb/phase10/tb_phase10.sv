`timescale 1ns/1ps
module tb_phase10;
`ifdef PHASE10_E4
    localparam integer ENGINES=4;
`elsif PHASE10_E2
    localparam integer ENGINES=2;
`else
    localparam integer ENGINES=1;
`endif
`ifdef PHASE10_ISOLATE
    localparam integer FRAMES=4;
`else
    localparam integer FRAMES=2;
`endif
    localparam integer SAMPLES=FRAMES*307200;
    localparam integer BLOCKS=FRAMES*300;
    reg clk=0,rst_n=0,vs=0,hs=0,de=0;
    reg [7:0] gray=0;
    wire out_vs,out_hs,out_de,out_bit;
    wire ref_vs,ref_hs,ref_de,ref_bit;
    canny_block_adaptive_phase10_top #(.ENGINE_COUNT(ENGINES)) u_dut (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),.per_frame_href(hs),
        .per_frame_clken(de),.per_img_y(gray),.mode_i(1'b1),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(out_vs),.post_frame_href(out_hs),
        .post_frame_clken(out_de),.post_img_bit(out_bit));
    canny_block_adaptive_phase9_top #(.BLOCK_W(32),.BLOCK_H(32),
        .HIST_BINS(32)) u_phase9 (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),.per_frame_href(hs),
        .per_frame_clken(de),.per_img_y(gray),.mode_i(1'b1),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(ref_vs),.post_frame_href(ref_hs),
        .post_frame_clken(ref_de),.post_img_bit(ref_bit));
    always #3 clk=~clk;
    reg [1:0] expected_class[0:SAMPLES-1];
    reg expected_edge[0:SAMPLES-1];
    reg observed_edge[0:SAMPLES-1];
    reg reference_edge[0:SAMPLES-1];
    reg [10:0] expected_low[0:BLOCKS-1],expected_high[0:BLOCKS-1];
    reg expected_active[0:BLOCKS-1];
    reg [27:0] isolated_threshold[0:299];
    reg isolated_edge[0:307199];
    integer fd,bfd,fields,iv,ih,id,ip,il,ihi;
    integer bf,bx,by,bpixels,bnonzero,bbin,bhigh,blow,bactive;
    integer input_pixels=0,nms_pixels=0,class_pixels=0,edge_pixels=0;
    integer reference_pixels=0,frames=0,frame_pixels=0,cycles=0;
    integer first_input=-1,first_output=-1,last_output=-1;
    integer frame_first=-1,previous_first=-1,frame_interval=-1;
    integer completed_stripes=0,ready_stripes=0;
    integer first_complete[0:FRAMES-1],adaptive_cycles[0:FRAMES-1];
    integer block_index,x,y,f,i;
    reg old_out_vs=0;
    string suite,path,prefix;
`ifdef PHASE10_DELAY_FIRST
    initial begin
        if (ENGINES<2) $fatal(1,"delayed-first test needs multiple engines");
        wait(rst_n && u_dut.ready[0] && u_dut.merge_stripe==0);
        force u_dut.grant[0]=1'b0;
        wait(u_dut.ready[1]);
        if (u_dut.merge_stripe!=0 || u_dut.merge_active)
            $fatal(1,"later stripe replayed before held first stripe");
        $display("PHASE10_OUT_OF_ORDER_READY_PASS later_engine_ready_first=1 replay_held=1");
        release u_dut.grant[0];
    end
`endif
    initial begin
`ifdef PHASE10_ISOLATE
        suite="isolate";path="results/phase6/isolate.stream";
`else
        suite="two";path="results/phase6/fixed.stream";
`endif
        prefix={"results/phase9/vectors/b32_h32_",suite};
        $readmemh({prefix,"_classes.mem"},expected_class);
        $readmemh({prefix,"_edges.mem"},expected_edge);
        bfd=$fopen({prefix,"_blocks.txt"},"r");
        if (!bfd) $fatal(1,"missing block oracle");
        for (i=0;i<BLOCKS;i=i+1) begin
            fields=$fscanf(bfd,"%d %d %d %d %d %d %d %d %d",
                bf,bx,by,bpixels,bnonzero,bbin,bhigh,blow,bactive);
            if (fields!=9 || bf!=i/300 || bx!=(i%300)%20 || by!=(i%300)/20)
                $fatal(1,"bad block oracle index=%0d",i);
            expected_low[i]=blow;expected_high[i]=bhigh;
            expected_active[i]=bactive;
        end
        $fclose(bfd);
        fd=$fopen(path,"r");if (!fd) $fatal(1,"missing input stream");
        repeat(4) @(negedge clk);rst_n=1;
        while (!$feof(fd)) begin
            fields=$fscanf(fd,"%d %d %d %d %d %d\n",iv,ih,id,ip,il,ihi);
            if (fields==6) begin
                @(negedge clk);vs=iv[0];hs=ih[0];de=id[0];gray=ip[7:0];
                if (ih && id) input_pixels=input_pixels+1;
            end
        end
        @(negedge clk);vs=0;hs=0;de=0;gray=0;
        repeat(90000) @(negedge clk);
        if (input_pixels!=SAMPLES || nms_pixels!=SAMPLES ||
            class_pixels!=SAMPLES || edge_pixels!=SAMPLES ||
            reference_pixels!=SAMPLES || frames!=FRAMES ||
            completed_stripes!=FRAMES*15 || ready_stripes!=FRAMES*15)
            $fatal(1,"count input=%0d nms=%0d class=%0d edge=%0d ref=%0d frames=%0d completed=%0d ready=%0d",
                input_pixels,nms_pixels,class_pixels,edge_pixels,reference_pixels,
                frames,completed_stripes,ready_stripes);
        for (i=0;i<SAMPLES;i=i+1)
            if (observed_edge[i] !== reference_edge[i])
                $fatal(1,"Phase9 direct mismatch engine=%0d pixel=%0d",ENGINES,i);
        for (i=0;i<ENGINES;i=i+1)
            $display("PHASE10_ENGINE_UTIL engine=%0d fill=%0d scan=%0d replay=%0d busy=%0d observed=%0d idle=%0d",
                i,u_dut.e_fill[i],u_dut.e_scan[i],u_dut.e_replay[i],
                u_dut.e_busy[i],last_output-first_input+1,
                last_output-first_input+1-u_dut.e_busy[i]);
        for (i=0;i<FRAMES;i=i+1)
            $display("PHASE10_ADAPT_SERVICE frame=%0d cycles=%0d",i,adaptive_cycles[i]);
        $display("PHASE10_RTL_PASS engines=%0d suite=%s frames=%0d pixels=%0d blocks=%0d mismatches=0 unknowns=0 first_latency=%0d frame_interval=%0d last_latency=%0d",
            ENGINES,suite,FRAMES,edge_pixels,BLOCKS,
            first_output-first_input,frame_interval,last_output-first_input);
        $fclose(fd);$finish;
    end
    always @(posedge clk) begin
        #1;
        if (rst_n) begin
            cycles=cycles+1;
            for (integer k=0;k<ENGINES;k=k+1) begin
                if (u_dut.stripe_complete_pulse[k]) begin
                    if (completed_stripes%15==0)
                        first_complete[completed_stripes/15]=cycles;
                    completed_stripes=completed_stripes+1;
                end
                if (u_dut.threshold_ready_pulse[k]) begin
                    if (ready_stripes%15==14)
                        adaptive_cycles[ready_stripes/15]=
                            cycles-first_complete[ready_stripes/15]+1;
                    ready_stripes=ready_stripes+1;
                end
            end
            if (first_input<0 && vs && hs && de) first_input=cycles;
            if (u_dut.nms_hs && u_dut.nms_de) nms_pixels=nms_pixels+1;
            if (u_dut.class_hs && u_dut.class_de) begin
                if (class_pixels>=SAMPLES ||
                    u_dut.class_value !== expected_class[class_pixels])
                    $fatal(1,"class mismatch E=%0d pixel=%0d got=%0d expected=%0d",
                        ENGINES,class_pixels,u_dut.class_value,expected_class[class_pixels]);
                f=class_pixels/307200;
                y=(class_pixels%307200)/640;
                x=class_pixels%640;
                block_index=f*300+(y/32)*20+x/32;
                if (u_dut.class_low !== expected_low[block_index] ||
                    u_dut.class_high !== expected_high[block_index] ||
                    u_dut.class_active !== expected_active[block_index])
                    $fatal(1,"threshold mismatch E=%0d f=%0d x=%0d y=%0d got=%0d/%0d active=%0d expected=%0d/%0d active=%0d",
                        ENGINES,f,x,y,u_dut.class_low,u_dut.class_high,
                        u_dut.class_active,expected_low[block_index],
                        expected_high[block_index],expected_active[block_index]);
`ifdef PHASE10_ISOLATE
                if (f==1 && x%32==0 && y%32==0)
                    isolated_threshold[(y/32)*20+x/32]=
                        {u_dut.class_active,5'd0,u_dut.class_high,u_dut.class_low};
                if (f==3 && x%32==0 && y%32==0 &&
                    isolated_threshold[(y/32)*20+x/32] !==
                    {u_dut.class_active,5'd0,u_dut.class_high,u_dut.class_low})
                    $fatal(1,"cross-frame threshold leakage");
`endif
                class_pixels=class_pixels+1;
            end
            if (out_hs && out_de) begin
                if (edge_pixels>=SAMPLES || out_bit !== expected_edge[edge_pixels])
                    $fatal(1,"edge mismatch E=%0d pixel=%0d got=%0d expected=%0d",
                        ENGINES,edge_pixels,out_bit,expected_edge[edge_pixels]);
                observed_edge[edge_pixels]=out_bit;
`ifdef PHASE10_ISOLATE
                if (edge_pixels>=307200 && edge_pixels<614400)
                    isolated_edge[edge_pixels-307200]=out_bit;
                if (edge_pixels>=921600 && edge_pixels<1228800 &&
                    isolated_edge[edge_pixels-921600] !== out_bit)
                    $fatal(1,"cross-frame edge leakage");
`endif
                if (first_output<0) first_output=cycles;
                if (frame_first<0) begin
                    frame_first=cycles;
                    if (previous_first>=0) frame_interval=cycles-previous_first;
                    previous_first=cycles;
                end
                last_output=cycles;edge_pixels=edge_pixels+1;frame_pixels=frame_pixels+1;
            end
            if (ref_hs && ref_de) begin
                if (reference_pixels>=SAMPLES || ref_bit !== expected_edge[reference_pixels])
                    $fatal(1,"Phase9 reference mismatch pixel=%0d",reference_pixels);
                reference_edge[reference_pixels]=ref_bit;
                reference_pixels=reference_pixels+1;
            end
            if (old_out_vs && !out_vs) begin
                if (frame_pixels!=307200)
                    $fatal(1,"output frame=%0d pixels=%0d",frames,frame_pixels);
                frames=frames+1;frame_pixels=0;frame_first=-1;
            end
            old_out_vs=out_vs;
        end
    end
endmodule
