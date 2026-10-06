`timescale 1ns/1ps
module tb_phase8_histogram;
    reg clk=0;
    always #3 clk=~clk;
    reg update_en=0,clear_en=0;
    reg [4:0] update_block=0;
    reg [10:0] update_magnitude=0;
    reg [9:0] clear_addr=0,scan_addr=0;
    wire [10:0] scan_count,scan_nonzero;
    histogram_unit_phase8 dut (
        .clk(clk),.update_en(update_en),.update_block(update_block),
        .update_magnitude(update_magnitude),.clear_en(clear_en),
        .clear_addr(clear_addr),.scan_addr(scan_addr),
        .scan_count(scan_count),.scan_nonzero(scan_nonzero));
    integer data_fd,expected_fd,fields,case_id,i,b,mag,block,n,expected_count;
    integer counts[0:31];
    initial begin
        data_fd=$fopen("results/phase8/hist_magnitudes.txt","r");
        expected_fd=$fopen("results/phase8/hist_expected.txt","r");
        if (!data_fd || !expected_fd) $fatal(1,"missing histogram vectors");
        for (case_id=0;case_id<10;case_id=case_id+1) begin
            fields=$fscanf(expected_fd,"%d %d",block,n);
            if (fields!=2) $fatal(1,"missing expected header %0d",case_id);
            for (b=0;b<32;b=b+1) begin
                fields=$fscanf(expected_fd,"%d",counts[b]);
                if (fields!=1) $fatal(1,"missing expected bin");
            end
            for (i=0;i<1024;i=i+1) begin
                fields=$fscanf(data_fd,"%d",mag);
                if (fields!=1) $fatal(1,"missing magnitude case=%0d i=%0d",case_id,i);
                @(negedge clk);
                update_en=1;update_block=block[4:0];update_magnitude=mag[10:0];
            end
            @(negedge clk);update_en=0;
            for (b=0;b<32;b=b+1) begin
                scan_addr={block[4:0],b[4:0]};
                #1;
                if (scan_count !== counts[b] || scan_nonzero !== n)
                    $fatal(1,"hist mismatch case=%0d bin=%0d got=%0d exp=%0d total=%0d exp_total=%0d",
                           case_id,b,scan_count,counts[b],scan_nonzero,n);
            end
            if (n>1024) $fatal(1,"histogram overflow case=%0d",case_id);
            for (i=0;i<640;i=i+1) begin
                @(negedge clk);clear_en=1;clear_addr=i[9:0];
            end
            @(negedge clk);clear_en=0;
        end
        $display("PHASE8_HISTOGRAM_PASS cases=10 bin_comparisons=320 overflow=0 mismatches=0");
        $fclose(data_fd);$fclose(expected_fd);$finish;
    end
endmodule
