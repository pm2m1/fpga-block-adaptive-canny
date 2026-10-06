`timescale 1ns/1ps
module tb_netlist_pixels;
  localparam integer PIXELS=307200, BYTES=38400;
  reg clk=0,resetn=0,start=0;
  reg [2:0] test_sel=0;
  wire tx;
  wire [3:0] led;
  reg [7:0] golden[0:BYTES-1];
  reg [7:0] input_expected[0:PIXELS-1];
  integer clock_cycle=0,pixels=0,unknowns=0,mismatches=0,first_bad=-1;
  integer input_pixels=0,input_mismatches=0;
  reg exp_bit;
  always #5 clk=~clk;
  canny_nexys_a7_phase11_top dut (
    .clk100mhz(clk),.cpu_resetn(resetn),.start_btn(start),
    .test_sel(test_sel),.uart_tx_o(tx),.led(led));
  initial $readmemh("results/phase11/monkey_golden.mem",golden);
  initial $readmemh("images/phase11/monkey_gray.mem",input_expected);
  // Primitive Q updates can race a posedge testbench process. Sample the
  // settled valid/data half a cycle before the consuming rising edge.
  always @(negedge clk) begin
    clock_cycle=clock_cycle+1;
    if (resetn && dut.stream_vs && dut.stream_hs) begin
      if (input_pixels>=PIXELS) $fatal(1,"extra input sample");
      if (dut.rom_q!==input_expected[input_pixels]) begin
        input_mismatches=input_mismatches+1;
        if (input_mismatches<5)
          $display("NETLIST_INPUT_MISMATCH n=%0d got=%0d expected=%0d",
            input_pixels,dut.rom_q,input_expected[input_pixels]);
      end
      input_pixels=input_pixels+1;
    end
    // u_core_n_4 enables the synthesized pixel counter both for its
    // start-event initialization and for valid output pixels. Exclude the
    // pre-input start event, which is not an edge pixel.
    if (resetn && dut.input_seen && dut.u_core_n_4) begin
      if (pixels>=PIXELS) $fatal(1,"extra valid output at cycle %0d",clock_cycle);
      exp_bit=golden[pixels>>3][7-(pixels&7)];
`ifdef PHASE11V_DIAGNOSTIC
      if (pixels>=1880 && pixels<2060)
        $display("NETLIST_SAMPLE n=%0d got=%b expected=%b",pixels,dut.out_edge,exp_bit);
`endif
      if (dut.out_edge!==0 && dut.out_edge!==1) unknowns=unknowns+1;
      if (dut.out_edge!==exp_bit) begin
        mismatches=mismatches+1;
        if (first_bad<0) first_bad=pixels;
        if (mismatches<5)
          $display("NETLIST_MISMATCH n=%0d x=%0d y=%0d got=%b expected=%b",
            pixels,pixels%640,pixels/640,dut.out_edge,exp_bit);
      end
      pixels=pixels+1;
`ifdef PHASE11V_DIAGNOSTIC
      if (pixels==2100) begin
        if (mismatches || input_mismatches || unknowns)
          $fatal(1,"diagnostic pixels=%0d mismatches=%0d input_mismatches=%0d unknowns=%0d",pixels,mismatches,input_mismatches,unknowns);
        $display("PHASE11V_DIAGNOSTIC_COMPLETE pixels=%0d mismatches=%0d input_samples=%0d input_mismatches=%0d",pixels,mismatches,input_pixels,input_mismatches);
        $finish;
      end
`endif
      if (pixels%50000==0) $display("NETLIST_PROGRESS pixels=%0d cycle=%0d",pixels,clock_cycle);
    end
  end
  initial begin
    repeat (12) @(negedge clk);
    resetn=1;
    repeat (12) @(negedge clk);
    start=1;
    repeat (5) @(negedge clk);
    start=0;
    wait(dut.frame_done===1'b1);
    repeat (2) @(posedge clk);
    if (pixels!=PIXELS || input_pixels!=PIXELS || mismatches || input_mismatches || unknowns)
      $fatal(1,"netlist pixels=%0d input=%0d mismatches=%0d input_mismatches=%0d unknowns=%0d first_bad=%0d",
        pixels,input_pixels,mismatches,input_mismatches,unknowns,first_bad);
    $display("PHASE11V_NETLIST_PIXELS_PASS pixels=%0d mismatches=0 unknowns=0",pixels);
    $finish;
  end
  initial begin
    repeat (500000) @(posedge clk);
    $fatal(1,"netlist timeout pixels=%0d",pixels);
  end
endmodule
