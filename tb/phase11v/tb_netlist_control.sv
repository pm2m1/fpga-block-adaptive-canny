`timescale 1ns/1ps
module tb_netlist_control;
  reg clk=0, resetn=0, start=0;
  reg [2:0] test_sel=0;
  wire tx;
  wire [3:0] led;
  integer cycle=0;
  integer first_done=-1;
  always #5 clk=~clk;
  canny_nexys_a7_phase11_top dut (
    .clk100mhz(clk),.cpu_resetn(resetn),.start_btn(start),
    .test_sel(test_sel),.uart_tx_o(tx),.led(led));
  always @(posedge clk) begin
    cycle=cycle+1;
    if (resetn && (^led===1'bx)) $fatal(1,"unknown LED at cycle %0d",cycle);
    if (resetn && (^tx===1'bx)) $fatal(1,"unknown UART TX at cycle %0d",cycle);
    if (resetn && dut.frame_done===1'b1 && first_done<0) begin
      first_done=cycle;
      $display("PHASE11V_NETLIST_FRAME_DONE cycle=%0d led=%b tx=%b",cycle,led,tx);
    end
  end
  initial begin
    repeat (12) @(negedge clk);
    resetn=1;
    repeat (12) @(negedge clk);
    start=1;
    repeat (5) @(negedge clk);
    start=0;
    wait(first_done>=0);
    repeat (20) @(posedge clk);
    $display("PHASE11V_NETLIST_CONTROL_PASS done_cycle=%0d",first_done);
    $finish;
  end
  initial begin
    repeat (500000) @(posedge clk);
    $fatal(1,"netlist timeout cycle=%0d",cycle);
  end
endmodule
