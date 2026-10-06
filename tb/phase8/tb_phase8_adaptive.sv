`timescale 1ns/1ps
module tb_phase8_adaptive;
    reg clk=0,rst_n=0,vs=0,hs=0,de=0;
    reg [7:0] gray=0;
    reg mode_port=1;
    always #3 clk=~clk;
    wire out_vs,out_hs,out_de,out_bit;
    canny_block_adaptive_phase8_top u_dut (
        .clk(clk),.rst_n(rst_n),.per_frame_vsync(vs),.per_frame_href(hs),
        .per_frame_clken(de),.per_img_y(gray),.mode_i(mode_port),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(out_vs),.post_frame_href(out_hs),
        .post_frame_clken(out_de),.post_img_bit(out_bit));
    reg [10:0] expected_mag[0:3071999];
    reg [1:0] expected_class[0:3071999];
    reg expected_edge[0:3071999];
    reg [10:0] expected_hist[0:95999];
    reg isolate_frame1_edges[0:307199];
    reg [27:0] isolate_frame1_thresholds[0:299];
    string suite,input_path,mag_path,class_path,edge_path,hist_path,block_path;
    integer expected_frames,expected_pixels,expected_blocks;
    integer fd,block_fd,fields,iv,ih,id,ip,il,ihigh;
    integer expected_frame,expected_bx,expected_by,expected_n,expected_bin;
    integer expected_hi,expected_lo,expected_active;
    integer input_pixels=0,nms_pixels=0,class_pixels=0,edge_pixels=0;
    integer stripes=0,blocks=0,frames=0,frame_pixels=0,cycles=0;
    integer first_input=-1,first_output=-1,last_output=-1;
    integer frame_first_cycle=-1,frame_last_cycle=-1;
    integer scan_bin_cycles=0,scan_drain_cycles=0,scan_clear_cycles=0;
    integer replay_request_cycles=0,replay_gap_cycles=0;
    integer b,k,hidx;
    reg old_out_vs=0;
    initial begin
`ifdef PHASE8_ISOLATE
        suite="isolate";
`elsif PHASE8_PATTERNS
        suite="patterns";
`elsif PHASE8_MIXED
        suite="mixed";
`else
        suite="adaptive";
`endif
        if (suite=="adaptive") begin
            expected_frames=2;input_path="results/phase6/fixed.stream";
        end else if (suite=="isolate") begin
            expected_frames=4;input_path="results/phase6/isolate.stream";
        end else if (suite=="patterns") begin
            expected_frames=10;input_path="results/phase8/patterns.stream";
        end else if (suite=="mixed") begin
            expected_frames=2;input_path="results/phase6/fixed.stream";
        end else $fatal(1,"unknown suite %s",suite);
        expected_pixels=expected_frames*307200;
        expected_blocks=expected_frames*300;
        mode_port=(suite=="mixed") ? 1'b0:1'b1;
        mag_path=$sformatf("results/phase8/%s_nms.mem",suite);
        class_path=$sformatf("results/phase8/%s_classes.mem",suite);
        edge_path=$sformatf("results/phase8/%s_edges.mem",suite);
        hist_path=$sformatf("results/phase8/%s_hist.mem",suite);
        block_path=$sformatf("results/phase8/%s_blocks.txt",suite);
        $readmemh(mag_path,expected_mag);
        $readmemh(class_path,expected_class);
        $readmemh(edge_path,expected_edge);
        $readmemh(hist_path,expected_hist);
        fd=$fopen(input_path,"r");
        block_fd=$fopen(block_path,"r");
        if (!fd || !block_fd) $fatal(1,"missing adaptive test input/oracle");
        repeat (4) @(negedge clk);rst_n=1;
        while (!$feof(fd)) begin
            fields=$fscanf(fd,"%d %d %d %d %d %d\n",iv,ih,id,ip,il,ihigh);
            if (fields==6) begin
                @(negedge clk);vs=iv[0];hs=ih[0];de=id[0];gray=ip[7:0];
                if (suite=="mixed" && input_pixels>=153600) mode_port=1'b1;
                if (ih && id) input_pixels=input_pixels+1;
            end
        end
        @(negedge clk);vs=0;hs=0;de=0;gray=0;
        repeat (25000) @(negedge clk);
        if (input_pixels!=expected_pixels || nms_pixels!=expected_pixels ||
            class_pixels!=expected_pixels || edge_pixels!=expected_pixels ||
            frames!=expected_frames || stripes!=expected_frames*15 ||
            blocks!=expected_blocks)
            $fatal(1,"counts in=%0d nms=%0d class=%0d edge=%0d frames=%0d stripes=%0d blocks=%0d",
                   input_pixels,nms_pixels,class_pixels,edge_pixels,frames,stripes,blocks);
        $display("PHASE8_ADAPTIVE_PASS suite=%s frames=%0d pixels=%0d blocks=%0d mismatches=0 unknowns=0 first_latency=%0d total_latency=%0d",
                 suite,frames,edge_pixels,blocks,first_output-first_input,last_output-first_input);
        $display("PHASE8_SCHEDULE suite=%s scan_bins=%0d scan_drain=%0d scan_clear=%0d replay_requests=%0d replay_gaps=%0d",
                 suite,scan_bin_cycles,scan_drain_cycles,scan_clear_cycles,
                 replay_request_cycles,replay_gap_cycles);
        $fclose(fd);$fclose(block_fd);$finish;
    end
    always @(posedge clk) begin
        #1;
        if (rst_n) begin
            cycles=cycles+1;
            if (u_dut.u_stripe.scan_state==2'd1) scan_bin_cycles=scan_bin_cycles+1;
            if (u_dut.u_stripe.scan_state==2'd3) scan_drain_cycles=scan_drain_cycles+1;
            if (u_dut.u_stripe.scan_state==2'd2) scan_clear_cycles=scan_clear_cycles+1;
            if (u_dut.u_stripe.read_request) replay_request_cycles=replay_request_cycles+1;
            if (u_dut.u_stripe.replay_gap) replay_gap_cycles=replay_gap_cycles+1;
            if (first_input<0 && vs && hs && de) first_input=cycles;
            if (suite=="mixed" && vs && hs && de) begin
                if (input_pixels>153600 && input_pixels<307200 &&
                    u_dut.mode_active !== 1'b0)
                    $fatal(1,"mid-frame mode changed active setting");
                if (input_pixels>307200 && u_dut.mode_active !== 1'b1)
                    $fatal(1,"next-frame mode not captured");
            end
            if (u_dut.nms_hs && u_dut.nms_de) begin
                if (nms_pixels>=expected_pixels) $fatal(1,"extra NMS");
                if (u_dut.nms_magnitude !== expected_mag[nms_pixels])
                    $fatal(1,"NMS mismatch pixel=%0d got=%0d expected=%0d",
                           nms_pixels,u_dut.nms_magnitude,expected_mag[nms_pixels]);
                nms_pixels=nms_pixels+1;
                if (nms_pixels%20480==0) stripes=stripes+1;
            end
            // On entry to CLEAR, the completed stripe histogram has not yet
            // been cleared. Check all 640 bins and all 20 threshold records.
            if (u_dut.u_stripe.scan_state==2'd2 && u_dut.u_stripe.scan_index==0 &&
                u_dut.u_stripe.bank_ready[u_dut.u_stripe.scan_bank]) begin
                for (b=0;b<20;b=b+1) begin
                    fields=$fscanf(block_fd,"%d %d %d %d %d %d %d %d",
                        expected_frame,expected_bx,expected_by,expected_n,
                        expected_bin,expected_hi,expected_lo,expected_active);
                    if (fields!=8 || expected_frame!=blocks/300 ||
                        expected_bx!=b || expected_by!=(blocks/20)%15)
                        $fatal(1,"block oracle metadata blocks=%0d",blocks);
                    if (u_dut.u_stripe.block_high[u_dut.u_stripe.scan_bank][b] !== expected_hi ||
                        u_dut.u_stripe.block_low[u_dut.u_stripe.scan_bank][b] !== expected_lo ||
                        u_dut.u_stripe.block_bin[u_dut.u_stripe.scan_bank][b] !== expected_bin ||
                        u_dut.u_stripe.block_active[u_dut.u_stripe.scan_bank][b] !== expected_active)
                        $fatal(1,"block threshold mismatch block=%0d got=%0d/%0d/%0d/%0d expected=%0d/%0d/%0d/%0d",
                           blocks,u_dut.u_stripe.block_bin[u_dut.u_stripe.scan_bank][b],
                           u_dut.u_stripe.block_high[u_dut.u_stripe.scan_bank][b],
                           u_dut.u_stripe.block_low[u_dut.u_stripe.scan_bank][b],
                           u_dut.u_stripe.block_active[u_dut.u_stripe.scan_bank][b],
                           expected_bin,expected_hi,expected_lo,expected_active);
                    if (suite=="isolate") begin
                        if (blocks>=300 && blocks<600)
                            isolate_frame1_thresholds[blocks-300]={expected_active[0],expected_bin[4:0],expected_hi[10:0],expected_lo[10:0]};
                        if (blocks>=900 && blocks<1200 &&
                            isolate_frame1_thresholds[blocks-900] !==
                            {expected_active[0],expected_bin[4:0],expected_hi[10:0],expected_lo[10:0]})
                            $fatal(1,"cross-frame threshold leakage block=%0d",blocks);
                    end
                    if (u_dut.u_stripe.scan_bank) begin
                        if (u_dut.u_stripe.u_hist1.nonzero_count[b] !== expected_n)
                            $fatal(1,"nonzero mismatch block=%0d",blocks);
                    end else if (u_dut.u_stripe.u_hist0.nonzero_count[b] !== expected_n)
                        $fatal(1,"nonzero mismatch block=%0d",blocks);
                    for (k=0;k<32;k=k+1) begin
                        hidx=(blocks/20)*640+b*32+k;
                        if (u_dut.u_stripe.scan_bank) begin
                            if (u_dut.u_stripe.u_hist1.hist[b*32+k] !== expected_hist[hidx])
                                $fatal(1,"hist mismatch block=%0d bin=%0d",blocks,k);
                        end else if (u_dut.u_stripe.u_hist0.hist[b*32+k] !== expected_hist[hidx])
                            $fatal(1,"hist mismatch block=%0d bin=%0d",blocks,k);
                    end
                    blocks=blocks+1;
                end
            end
            if (u_dut.class_hs && u_dut.class_de) begin
                if (class_pixels>=expected_pixels) $fatal(1,"extra class");
                if (u_dut.class_value !== expected_class[class_pixels])
                    $fatal(1,"class mismatch pixel=%0d got=%0d expected=%0d",
                           class_pixels,u_dut.class_value,expected_class[class_pixels]);
                class_pixels=class_pixels+1;
            end
            if (out_hs && out_de) begin
                if (edge_pixels>=expected_pixels) $fatal(1,"extra edge");
                if (out_bit !== expected_edge[edge_pixels])
                    $fatal(1,"edge mismatch pixel=%0d got=%0d expected=%0d",
                           edge_pixels,out_bit,expected_edge[edge_pixels]);
                if (suite=="isolate") begin
                    if (edge_pixels>=307200 && edge_pixels<614400)
                        isolate_frame1_edges[edge_pixels-307200]=out_bit;
                    if (edge_pixels>=921600 && edge_pixels<1228800 &&
                        isolate_frame1_edges[edge_pixels-921600] !== out_bit)
                        $fatal(1,"cross-frame edge leakage pixel=%0d",edge_pixels);
                end
                if (first_output<0) first_output=cycles;
                if (frame_first_cycle<0) frame_first_cycle=cycles;
                last_output=cycles;
                frame_last_cycle=cycles;
                edge_pixels=edge_pixels+1;frame_pixels=frame_pixels+1;
            end
            if (old_out_vs && !out_vs) begin
                if (frame_pixels!=307200)
                    $fatal(1,"frame pixel count frame=%0d pixels=%0d",frames,frame_pixels);
                $display("PHASE8_FRAME_CYCLES suite=%s frame=%0d first=%0d last=%0d span=%0d pixels=%0d",
                         suite,frames,frame_first_cycle,frame_last_cycle,
                         frame_last_cycle-frame_first_cycle+1,frame_pixels);
                frames=frames+1;frame_pixels=0;
                frame_first_cycle=-1;frame_last_cycle=-1;
            end
            old_out_vs=out_vs;
        end
    end
endmodule
