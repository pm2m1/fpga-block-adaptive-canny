`timescale 1ns / 1ps
module tb_threshold_phase6;
    reg [10:0] magnitude=0, low=0, high=1;
    reg [3:0] direction=1;
    wire [16:0] gra_path;
    canny_threshold_classify_phase6 u_dut (
        .magnitude(magnitude),.direction(direction),
        .threshold_low(low),.threshold_high(high),.gra_path(gra_path));
    integer fd, fields, m, d, l, h, expected, tested=0;
    initial begin
        fd=$fopen("results/phase6/boundary_vectors.txt","r");
        if (!fd) $fatal(1,"Cannot open boundary vectors");
        while (!$feof(fd)) begin
            fields=$fscanf(fd,"%d %d %d %d %d\n",m,d,l,h,expected);
            if (fields==5) begin
                if (l>=h) $fatal(1,"PHASE6_INVALID_THRESHOLDS low=%0d high=%0d",l,h);
                magnitude=m[10:0]; direction=d[3:0];
                low=l[10:0];high=h[10:0];
                #1;
                if (gra_path !== expected[16:0])
                    $fatal(1,"PHASE6_BOUNDARY_MISMATCH m=%0d d=%0d low=%0d high=%0d RTL=%0d Python=%0d",
                           m,d,l,h,gra_path,expected);
                tested=tested+1;
            end
        end
        $fclose(fd);
        if (tested<300) $fatal(1,"Insufficient boundary vectors %0d",tested);
        $display("PHASE6_BOUNDARY_PASS vectors=%0d mismatches=0",tested);
        $finish;
    end
endmodule
