`timescale 1ns/1ps
module tb_phase8_threshold;
    reg [10:0] cumulative_i=0,bin_count_i=0,nonzero_i=0;
    reg [4:0] bin_i=0;
    wire [10:0] cumulative_o,high_o,low_o;
    wire crossing_o;
    adaptive_threshold_step_phase8 dut (
        .cumulative_i(cumulative_i),.bin_count_i(bin_count_i),
        .nonzero_i(nonzero_i),.bin_i(bin_i),
        .cumulative_o(cumulative_o),.crossing_o(crossing_o),
        .high_o(high_o),.low_o(low_o));
    integer fd,fields,case_id,b,n,expect_bin,expect_high,expect_low,expect_active;
    integer hist[0:31];
    integer selected,got_high,got_low,got_active;
    initial begin
        fd=$fopen("results/phase8/threshold_vectors.txt","r");
        if (!fd) $fatal(1,"missing threshold vectors");
        for (case_id=0;case_id<109;case_id=case_id+1) begin
            fields=$fscanf(fd,"%d %d %d %d %d",n,expect_bin,expect_high,expect_low,expect_active);
            if (fields!=5) $fatal(1,"missing threshold header case=%0d",case_id);
            for (b=0;b<32;b=b+1) begin
                fields=$fscanf(fd,"%d",hist[b]);
                if (fields!=1) $fatal(1,"missing bin case=%0d",case_id);
            end
            cumulative_i=0;nonzero_i=n[10:0];
            selected=-1;got_high=0;got_low=0;got_active=0;
            for (b=31;b>=0;b=b-1) begin
                bin_i=b[4:0];bin_count_i=hist[b][10:0];
                #1;
                if (crossing_o && selected<0) begin
                    selected=b;got_high=high_o;got_low=low_o;got_active=1;
                end
                cumulative_i=cumulative_o;
            end
            if (!got_active) selected=0;
            if (selected!=expect_bin || got_high!=expect_high ||
                got_low!=expect_low || got_active!=expect_active)
                $fatal(1,"threshold mismatch case=%0d got=%0d/%0d/%0d/%0d exp=%0d/%0d/%0d/%0d",
                       case_id,selected,got_high,got_low,got_active,
                       expect_bin,expect_high,expect_low,expect_active);
        end
        $display("PHASE8_THRESHOLD_PASS histograms=109 mismatches=0");
        $fclose(fd);$finish;
    end
endmodule
