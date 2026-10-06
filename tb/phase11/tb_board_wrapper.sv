`timescale 1ns/1ps
module tb_board_wrapper;
  localparam integer PIXELS=307200, BYTES=38400;
  reg clk=0, resetn=0, start=0;
  reg [2:0] test_sel=0;
  wire tx;
  wire [3:0] leds;
  reg [7:0] expected[0:BYTES-1];
  reg [7:0] input_mem[0:PIXELS-1];
  string golden_file;
  integer test_id, input_count=0, output_count=0, unknown_count=0;
  integer mismatch_count=0, first_bad=-1, i;
`ifdef PHASE11_CAPTURE_UART
  localparam integer PACKET_BYTES=38426;
  reg [7:0] packet[0:PACKET_BYTES-1];
  reg [7:0] rx_byte;
  integer rx_count=0, rx_bit, output_file, packet_i;
  initial forever begin
    @(negedge tx);
    #10;
    if (tx!==0) $fatal(1,"bad UART start bit");
    for (rx_bit=0;rx_bit<8;rx_bit=rx_bit+1) begin
      #20;
      rx_byte[rx_bit]=tx;
    end
    #20;
    if (tx!==1) $fatal(1,"bad UART stop bit at byte %0d",rx_count);
    if (rx_count<PACKET_BYTES) packet[rx_count]=rx_byte;
    rx_count=rx_count+1;
  end
`endif
  always #5 clk=~clk;
  canny_nexys_a7_phase11_top #(
`ifdef PHASE11_CAPTURE_UART
    .UART_DIV(2)
`else
    .UART_DIV(868)
`endif
  ) dut (
    .clk100mhz(clk),.cpu_resetn(resetn),.start_btn(start),
    .test_sel(test_sel),.uart_tx_o(tx),.led(leds));

  function automatic [7:0] expected_pattern(input integer tid,
      input integer n);
    integer px,py;
    begin
      px=n%640; py=n/640;
      case (tid)
        0: expected_pattern=input_mem[n];
        1: expected_pattern=0;
        2: expected_pattern=255;
        3: expected_pattern=px>=320 ? 255:0;
        4: expected_pattern=py>=240 ? 255:0;
        5: expected_pattern=(((px/8)+(py/4))%2) ? 255:0;
        default: expected_pattern=0;
      endcase
    end
  endfunction
  always @(posedge clk) if (resetn && dut.rst_n) begin
    if (dut.stream_vs && dut.stream_hs && dut.stream_de) begin
      if (input_count>=PIXELS) $fatal(1,"input overflow");
      if ($isunknown(dut.stream_pixel)) $fatal(1,"unknown input at %0d",input_count);
      if (dut.stream_pixel!==expected_pattern(test_id,input_count))
        $fatal(1,"input mismatch n=%0d rtl=%0d expected=%0d",
          input_count,dut.stream_pixel,expected_pattern(test_id,input_count));
      input_count=input_count+1;
    end
    if (dut.out_hs && dut.out_de) begin
      if (output_count>=PIXELS) $fatal(1,"output overflow");
      if ($isunknown(dut.out_edge)) unknown_count=unknown_count+1;
      output_count=output_count+1;
    end
  end
  initial begin
`ifdef PHASE11_BLACK
    test_id=1; golden_file="results/phase11/black_golden.mem";
`elsif PHASE11_WHITE
    test_id=2; golden_file="results/phase11/white_golden.mem";
`elsif PHASE11_VERTICAL
    test_id=3; golden_file="results/phase11/vertical_golden.mem";
`elsif PHASE11_HORIZONTAL
    test_id=4; golden_file="results/phase11/horizontal_golden.mem";
`elsif PHASE11_CHECKERBOARD
    test_id=5; golden_file="results/phase11/checkerboard_golden.mem";
`else
    test_id=0; golden_file="results/phase11/monkey_golden.mem";
`endif
    if (test_id<0 || test_id>5) $fatal(1,"bad test ID");
    $readmemh(golden_file,expected);
    $readmemh("images/phase11/monkey_gray.mem",input_mem);
    test_sel=test_id[2:0];
    repeat (8) @(posedge clk);
    resetn=1;
    repeat (8) @(posedge clk);
    start=1;
    repeat (5) @(posedge clk);
    start=0;
    wait(dut.frame_done);
    repeat (3) @(posedge clk);
    if (input_count!=PIXELS || output_count!=PIXELS || dut.pixel_count!=PIXELS)
      $fatal(1,"pixel counts input=%0d output=%0d stored=%0d",
          input_count,output_count,dut.pixel_count);
    for (i=0;i<BYTES;i=i+1) begin
      if ($isunknown(dut.edge_mem[i])) unknown_count=unknown_count+8;
      if (dut.edge_mem[i]!==expected[i]) begin
        mismatch_count=mismatch_count+1;
        if (first_bad<0) first_bad=i;
      end
    end
    if (mismatch_count || unknown_count || dut.error_flag)
      $fatal(1,"wrapper mismatch bytes=%0d first=%0d unknown=%0d error=%0d",
          mismatch_count,first_bad,unknown_count,dut.error_flag);
    $display("PHASE11_WRAPPER_PASS test=%0d input=%0d output=%0d bytes=%0d mismatches=0 unknowns=0 processing_cycles=%0d first_output_latency=%0d",
      test_id,input_count,output_count,BYTES,dut.processing_cycles,
      dut.first_output_cycle-dut.input_first_cycle);
`ifdef PHASE11_CAPTURE_UART
    wait(rx_count==PACKET_BYTES);
    output_file=$fopen("results/phase11/sim_uart_packet.bin","wb");
    if (!output_file) $fatal(1,"cannot open packet output");
    for (packet_i=0;packet_i<PACKET_BYTES;packet_i=packet_i+1)
      $fwrite(output_file,"%c",packet[packet_i]);
    $fclose(output_file);
    $display("PHASE11_UART_PACKET_PASS bytes=%0d",rx_count);
`endif
    $finish;
  end
  initial begin
    repeat (1500000) @(posedge clk);
    $fatal(1,"wrapper timeout input=%0d output=%0d state=%0d",
      input_count,output_count,dut.state);
  end
endmodule
