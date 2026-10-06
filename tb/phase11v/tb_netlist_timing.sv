`timescale 1ns/1ps
module tb_netlist_timing;
  reg clk=0,resetn=0,start=0;
  reg [2:0] test_sel=1; // directed all-black input
  wire tx;
  wire [3:0] led;
  integer cycles=0,valid_samples=0,unknowns=0,nonzero=0;
  always #5 clk=~clk;
  canny_nexys_a7_phase11_top dut (
    .clk100mhz(clk),.cpu_resetn(resetn),.start_btn(start),
    .test_sel(test_sel),.uart_tx_o(tx),.led(led));
  // SDF propagation may take most of a 10 ns cycle. Observe 0.2 ns before
  // the next active clock edge, not at the launching edge.
  always @(posedge clk) begin
    cycles=cycles+1;
    #9.8;
    if (resetn && dut.input_seen && dut.u_core_n_4) begin
      valid_samples=valid_samples+1;
      if (dut.out_edge!==0 && dut.out_edge!==1) unknowns=unknowns+1;
      if (dut.out_edge===1'b1) nonzero=nonzero+1;
    end
    if (resetn && (^tx===1'bx || ^led===1'bx))
      $fatal(1,"unknown UART or LED control at cycle %0d",cycles);
  end
  initial begin
    repeat (12) @(negedge clk);
    resetn=1;
    repeat (12) @(negedge clk);
    start=1;
    repeat (5) @(negedge clk);
    start=0;
    #250000;
    if (valid_samples<100 || unknowns || nonzero)
      $fatal(1,"SDF directed check valid=%0d unknowns=%0d nonzero=%0d",valid_samples,unknowns,nonzero);
    $display("PHASE11V_SDF_DIRECTED_PASS period_ns=10 valid_samples=%0d unknowns=0 black_edges=0",valid_samples);
    $finish;
  end
endmodule
