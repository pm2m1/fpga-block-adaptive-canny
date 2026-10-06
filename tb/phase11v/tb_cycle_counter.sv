`timescale 1ns/1ps
module tb_cycle_counter;
  tb_board_wrapper ref_tb();
  integer clock_cycle=0;
  integer first_input=-1,first_output=-1,last_output=-1;
  integer input_pixels=0,output_pixels=0;
  reg checked=0;
  always @(posedge ref_tb.clk) begin
    clock_cycle=clock_cycle+1;
    if (ref_tb.resetn && ref_tb.dut.rst_n) begin
      if (ref_tb.dut.stream_vs && ref_tb.dut.stream_hs && ref_tb.dut.stream_de) begin
        if (first_input<0) first_input=clock_cycle;
        input_pixels=input_pixels+1;
      end
      if (ref_tb.dut.out_hs && ref_tb.dut.out_de) begin
        if (first_output<0) first_output=clock_cycle;
        last_output=clock_cycle;
        output_pixels=output_pixels+1;
      end
      if (ref_tb.dut.frame_done && !checked) begin
        checked=1;
        if (first_input<0 || first_output<0 || last_output<0)
          $fatal(1,"missing first/last markers");
        if (ref_tb.dut.processing_cycles !== last_output-first_input+1)
          $fatal(1,"processing counter rtl=%0d independent=%0d",
            ref_tb.dut.processing_cycles,last_output-first_input+1);
        if (ref_tb.dut.first_output_cycle-ref_tb.dut.input_first_cycle !== first_output-first_input)
          $fatal(1,"first-output latency differs rtl=%0d independent=%0d",
            ref_tb.dut.first_output_cycle-ref_tb.dut.input_first_cycle,first_output-first_input);
        if (input_pixels!=307200 || output_pixels!=307200)
          $fatal(1,"pixel counts input=%0d output=%0d",input_pixels,output_pixels);
        $display("PHASE11V_CYCLE_COUNTER_PASS first_input=%0d first_output=%0d last_output=%0d processing=%0d pixels=%0d",
          first_input,first_output,last_output,last_output-first_input+1,output_pixels);
      end
    end
  end
endmodule
