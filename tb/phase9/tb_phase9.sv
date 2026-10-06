`timescale 1ns/1ps
module tb_phase9;
`ifdef PHASE9_B64
    localparam integer BLOCK=64;
`else
    localparam integer BLOCK=32;
`endif
`ifdef PHASE9_H8
    localparam integer BINS=8;
`elsif PHASE9_H16
    localparam integer BINS=16;
`else
    localparam integer BINS=32;
`endif
    localparam integer BLOCKS_PER_FRAME=(640/BLOCK)*((480+BLOCK-1)/BLOCK);
`ifdef PHASE9_ISOLATE
    localparam integer FRAMES=4;
`else
    localparam integer FRAMES=2;
`endif
    localparam integer SAMPLES=FRAMES*307200;
    reg clk=0,rst_n=0,vs=0,hs=0,de=0;
    reg [7:0] gray=0;
`ifdef PHASE9_FIXED
    localparam MODE=0;
`else
    localparam MODE=1;
`endif
    wire out_vs,out_hs,out_de,out_bit;
    canny_block_adaptive_phase9_top #(.BLOCK_W(BLOCK),.BLOCK_H(BLOCK),
        .HIST_BINS(BINS)) u_dut (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),.per_frame_href(hs),
        .per_frame_clken(de),.per_img_y(gray),.mode_i(MODE),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(out_vs),.post_frame_href(out_hs),
        .post_frame_clken(out_de),.post_img_bit(out_bit));
    always #3 clk=~clk;
    reg [10:0] expected_mag[0:SAMPLES-1];
    reg [1:0] expected_class[0:SAMPLES-1];
    reg expected_edge[0:SAMPLES-1];
    reg [27:0] isolated_threshold[0:BLOCKS_PER_FRAME-1];
    reg isolated_edge[0:307199];
    integer fd,block_fd,fields,iv,ih,id,ip,il,ihigh;
    integer ef,ebx,eby,epixels,en,ebin,ehi,elo,eactive;
    integer input_pixels=0,nms_pixels=0,class_pixels=0,edge_pixels=0;
    integer blocks=0,frames=0,frame_pixels=0,cycles=0;
    integer first_input=-1,first_output=-1,last_output=-1;
    integer frame_first=-1,previous_first=-1,frame_interval=-1;
    reg old_out_vs=0;
    string suite,prefix,path;
    initial begin
`ifdef PHASE9_ISOLATE
        suite="isolate";path="results/phase6/isolate.stream";
        $readmemh("results/phase8/isolate_nms.mem",expected_mag);
`else
        suite="two";path="results/phase6/fixed.stream";
        $readmemh("results/phase8/adaptive_nms.mem",expected_mag);
`endif
        prefix=$sformatf("results/phase9/vectors/b%0d_h%0d_%s",BLOCK,BINS,suite);
        if (MODE) begin
            $readmemh({prefix,"_classes.mem"},expected_class);
            $readmemh({prefix,"_edges.mem"},expected_edge);
        end else begin
            $readmemh({prefix,"_fixed_classes.mem"},expected_class);
            $readmemh({prefix,"_fixed_edges.mem"},expected_edge);
        end
        fd=$fopen(path,"r");
        block_fd=$fopen({prefix,"_blocks.txt"},"r");
        if (!fd || !block_fd) $fatal(1,"missing Phase9 stimulus/oracle");
        repeat(4) @(negedge clk);rst_n=1;
        while (!$feof(fd)) begin
            fields=$fscanf(fd,"%d %d %d %d %d %d\n",iv,ih,id,ip,il,ihigh);
            if (fields==6) begin
                @(negedge clk);vs=iv[0];hs=ih[0];de=id[0];gray=ip[7:0];
                if (ih && id) input_pixels=input_pixels+1;
            end
        end
        @(negedge clk);vs=0;hs=0;de=0;gray=0;
        repeat(90000) @(negedge clk);
        if (input_pixels!=SAMPLES || nms_pixels!=SAMPLES ||
            class_pixels!=SAMPLES || edge_pixels!=SAMPLES ||
            blocks!=FRAMES*BLOCKS_PER_FRAME || frames!=FRAMES)
            $fatal(1,"count in=%0d nms=%0d class=%0d edge=%0d blocks=%0d frames=%0d",
                   input_pixels,nms_pixels,class_pixels,edge_pixels,blocks,frames);
        $display("PHASE9_RTL_PASS block=%0d bins=%0d mode=%0d suite=%s frames=%0d pixels=%0d blocks=%0d mismatches=0 unknowns=0 first_latency=%0d frame_interval=%0d last_latency=%0d",
                 BLOCK,BINS,MODE,suite,FRAMES,edge_pixels,blocks,
                 first_output-first_input,frame_interval,last_output-first_input);
        $fclose(fd);$fclose(block_fd);$finish;
    end
    always @(posedge clk) begin
        #1;
        if (rst_n) begin
            cycles=cycles+1;
            if (first_input<0 && vs && hs && de) first_input=cycles;
            if (u_dut.nms_hs && u_dut.nms_de) begin
                if (nms_pixels>=SAMPLES ||
                    u_dut.nms_magnitude !== expected_mag[nms_pixels])
                    $fatal(1,"NMS mismatch pixel=%0d got=%0d expected=%0d",
                           nms_pixels,u_dut.nms_magnitude,expected_mag[nms_pixels]);
                nms_pixels=nms_pixels+1;
            end
            if (u_dut.u_stripe.scan_state==2'd2 &&
                u_dut.u_stripe.scan_index==0 &&
                u_dut.u_stripe.bank_ready[u_dut.u_stripe.scan_bank]) begin
                for (integer b=0;b<640/BLOCK;b=b+1) begin
                    fields=$fscanf(block_fd,"%d %d %d %d %d %d %d %d %d",
                        ef,ebx,eby,epixels,en,ebin,ehi,elo,eactive);
                    if (fields!=9 || ef!=blocks/BLOCKS_PER_FRAME ||
                        ebx!=b || eby!=(blocks/(640/BLOCK))%((480+BLOCK-1)/BLOCK) ||
                        epixels!=BLOCK*((eby==7 && BLOCK==64)?32:BLOCK))
                        $fatal(1,"block metadata mismatch index=%0d",blocks);
                    if (u_dut.u_stripe.block_high[u_dut.u_stripe.scan_bank][b] !== ehi ||
                        u_dut.u_stripe.block_low[u_dut.u_stripe.scan_bank][b] !== elo ||
                        u_dut.u_stripe.block_bin[u_dut.u_stripe.scan_bank][b] !== ebin ||
                        u_dut.u_stripe.block_active[u_dut.u_stripe.scan_bank][b] !== eactive)
                        $fatal(1,"threshold mismatch block=%0d got=%0d/%0d expected=%0d/%0d",
                               blocks,u_dut.u_stripe.block_high[u_dut.u_stripe.scan_bank][b],
                               u_dut.u_stripe.block_low[u_dut.u_stripe.scan_bank][b],ehi,elo);
`ifdef PHASE9_ISOLATE
                    if (blocks>=BLOCKS_PER_FRAME && blocks<2*BLOCKS_PER_FRAME)
                        isolated_threshold[blocks-BLOCKS_PER_FRAME]=
                            {eactive[0],ebin[4:0],ehi[10:0],elo[10:0]};
                    if (blocks>=3*BLOCKS_PER_FRAME &&
                        isolated_threshold[blocks-3*BLOCKS_PER_FRAME] !==
                        {eactive[0],ebin[4:0],ehi[10:0],elo[10:0]})
                        $fatal(1,"threshold frame leakage block=%0d",blocks);
`endif
                    blocks=blocks+1;
                end
            end
            if (u_dut.class_hs && u_dut.class_de) begin
                if (class_pixels>=SAMPLES ||
                    u_dut.class_value !== expected_class[class_pixels])
                    $fatal(1,"class mismatch pixel=%0d got=%0d expected=%0d",
                           class_pixels,u_dut.class_value,expected_class[class_pixels]);
                class_pixels=class_pixels+1;
            end
            if (out_hs && out_de) begin
                if (edge_pixels>=SAMPLES || out_bit !== expected_edge[edge_pixels])
                    $fatal(1,"edge mismatch pixel=%0d got=%0d expected=%0d",
                           edge_pixels,out_bit,expected_edge[edge_pixels]);
`ifdef PHASE9_ISOLATE
                if (edge_pixels>=307200 && edge_pixels<614400)
                    isolated_edge[edge_pixels-307200]=out_bit;
                if (edge_pixels>=921600 && edge_pixels<1228800 &&
                    isolated_edge[edge_pixels-921600] !== out_bit)
                    $fatal(1,"edge frame leakage pixel=%0d",edge_pixels);
`endif
                if (first_output<0) first_output=cycles;
                if (frame_first<0) begin
                    frame_first=cycles;
                    if (previous_first>=0) frame_interval=cycles-previous_first;
                    previous_first=cycles;
                end
                last_output=cycles;edge_pixels=edge_pixels+1;frame_pixels=frame_pixels+1;
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
