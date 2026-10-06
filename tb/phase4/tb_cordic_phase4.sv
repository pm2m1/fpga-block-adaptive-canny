`timescale 1ns / 1ps
module tb_cordic_phase4;
    localparam integer LATENCY = 16;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg [10:0] abs_gx = 0, abs_gy = 0;
    reg sign_gx = 1, sign_gy = 1;
    reg in_valid = 0;
    wire [10:0] magnitude;
    wire [3:0] direction;
    wire out_vsync, out_href, out_valid;
    cordic_gradient_phase4 u_dut (
        .clk(clk), .rst_n(rst_n), .abs_gx(abs_gx), .abs_gy(abs_gy),
        .sign_gx(sign_gx), .sign_gy(sign_gy),
        .in_vsync(in_valid), .in_href(in_valid), .in_valid(in_valid),
        .magnitude(magnitude), .direction(direction),
        .out_vsync(out_vsync), .out_href(out_href), .out_valid(out_valid));

    integer expected_mag [0:LATENCY-1];
    integer expected_dir [0:LATENCY-1];
    integer expected_valid [0:LATENCY-1];
    integer fd, fields, reset_value, gx_value, gy_value, sx_value, sy_value;
    integer valid_value, mag_value, dir_value, i;
    integer vectors_tested = 0, mismatches = 0, unknown_outputs = 0;

    task check_cycle;
        begin
            @(posedge clk);
            if (!rst_n) begin
                for (i=0; i<LATENCY; i=i+1) begin
                    expected_mag[i] = 0;
                    expected_dir[i] = 1;
                    expected_valid[i] = 0;
                end
            end else begin
                for (i=LATENCY-1; i>0; i=i-1) begin
                    expected_mag[i] = expected_mag[i-1];
                    expected_dir[i] = expected_dir[i-1];
                    expected_valid[i] = expected_valid[i-1];
                end
                expected_mag[0] = mag_value;
                expected_dir[0] = dir_value;
                expected_valid[0] = valid_value;
            end
            #1;
            if ({out_vsync,out_href,out_valid} !== {3{expected_valid[LATENCY-1] != 0}}) begin
                mismatches = mismatches + 1;
                $fatal(1, "PHASE4_CONTROL_MISMATCH cycle=%0d got=%b%b%b expected=%0d",
                       vectors_tested, out_vsync,out_href,out_valid,expected_valid[LATENCY-1]);
            end
            if (expected_valid[LATENCY-1] != 0) begin
                vectors_tested = vectors_tested + 1;
                if ((^magnitude === 1'bx) || (^direction === 1'bx)) begin
                    unknown_outputs = unknown_outputs + 1;
                    $fatal(1, "PHASE4_UNKNOWN_OUTPUT vector=%0d", vectors_tested);
                end
                if ((magnitude !== expected_mag[LATENCY-1][10:0]) ||
                    (direction !== expected_dir[LATENCY-1][3:0])) begin
                    mismatches = mismatches + 1;
                    $fatal(1, "PHASE4_NUMERIC_MISMATCH vector=%0d got_mag=%0d exp_mag=%0d got_dir=%b exp_dir=%b",
                           vectors_tested,magnitude,expected_mag[LATENCY-1],direction,expected_dir[LATENCY-1]);
                end
            end
        end
    endtask

    initial begin
        for (i=0; i<LATENCY; i=i+1) begin
            expected_mag[i]=0; expected_dir[i]=1; expected_valid[i]=0;
        end
        fd = $fopen("results/phase4/cordic_vectors.txt", "r");
        if (fd == 0) $fatal(1,"Cannot open Phase-4 vectors");
        while (!$feof(fd)) begin
            fields = $fscanf(fd,"%d %d %d %d %d %d %d %d\n",
                             reset_value,gx_value,gy_value,sx_value,sy_value,
                             valid_value,mag_value,dir_value);
            if (fields == 8) begin
                @(negedge clk);
                rst_n = reset_value[0];
                abs_gx = gx_value[10:0]; abs_gy = gy_value[10:0];
                sign_gx = sx_value[0]; sign_gy = sy_value[0];
                in_valid = valid_value[0];
                check_cycle();
            end
        end
        $fclose(fd);
        for (integer flush=0; flush<LATENCY+1; flush=flush+1) begin
            @(negedge clk);
            rst_n=1; abs_gx=0; abs_gy=0; sign_gx=1; sign_gy=1;
            in_valid=0; valid_value=0; mag_value=0; dir_value=1;
            check_cycle();
        end
        $display("PHASE4_CORDIC_UNIT_TEST PASS vectors_tested=%0d mismatches=%0d unknown_outputs=%0d",
                 vectors_tested,mismatches,unknown_outputs);
        $finish;
    end
endmodule
