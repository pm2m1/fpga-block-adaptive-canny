`default_nettype none
// Self-contained Nexys A7-100T board validation, not a new Canny algorithm.
// Single shot per reset/start. No camera, DDR, or RGB conversion.
module canny_nexys_a7_phase11_top #(
    parameter ROM_FILE="images/phase11/monkey_gray.mem",
    parameter integer UART_DIV=868
) (
    input wire clk100mhz,cpu_resetn,start_btn,
    input wire [2:0] test_sel,
    output wire uart_tx_o,
    output wire [3:0] led
);
    localparam integer WIDTH=640,HEIGHT=480,PIXELS=307200,BYTES=38400;
    localparam integer HEADER_BYTES=22,TOTAL_BYTES=HEADER_BYTES+BYTES+4;
    localparam [3:0] S_IDLE=0,S_PRE=1,S_ACTIVE=2,S_BLANK=3,
        S_POST=4,S_END=5,S_WAIT=6,S_TX=7,S_DONE=8;
    reg [1:0] reset_pipe=0;
    // The native 100 MHz oscillator is always running; sample reset into
    // this clock domain before any BRAM address/control state uses it.
    always @(posedge clk100mhz)
        if (!cpu_resetn) reset_pipe<=0;
        else reset_pipe<={reset_pipe[0],1'b1};
    wire rst_n=reset_pipe[1];
    reg [1:0] start_pipe;
    reg start_prev;
    always @(posedge clk100mhz) begin
        if (!rst_n) begin start_pipe<=0;start_prev<=0;end
        else begin start_pipe<={start_pipe[0],start_btn};start_prev<=start_pipe[1];end
    end
    wire start_pulse=start_pipe[1] && !start_prev;

    reg [7:0] image_rom[0:PIXELS-1];
    initial $readmemh(ROM_FILE,image_rom);
    reg [7:0] rom_q,pattern_q;
    reg [7:0] edge_mem[0:BYTES-1];
    reg [7:0] edge_read_q;
    reg [18:0] image_addr,pixel_count;
    reg [15:0] payload_addr;
    reg [9:0] x;
    reg [8:0] y;
    reg [7:0] pre_count,blank_count,post_count,end_count;
    reg [3:0] state;
    reg [2:0] selected_test;
    reg stream_vs,stream_hs,stream_de;
    wire [7:0] stream_pixel=selected_test==0 ? rom_q:pattern_q;
    reg [7:0] pack_shift;
    reg [31:0] cycles,input_first_cycle,first_output_cycle,
        last_output_cycle,processing_cycles;
    reg input_seen,output_seen,frame_done,error_flag;
    reg [15:0] tx_index;
    reg [31:0] crc;
    wire tx_ready;
    wire tx_valid=state==S_TX && tx_index<TOTAL_BYTES;
    reg [7:0] tx_data;
    wire out_vs,out_hs,out_de,out_edge;

    function [7:0] procedural;
        input [2:0] which;
        input [9:0] px;
        input [8:0] py;
        begin
            case (which)
                3'd1: procedural=8'd0;
                3'd2: procedural=8'd255;
                3'd3: procedural=px>=320 ? 8'd255:8'd0;
                3'd4: procedural=py>=240 ? 8'd255:8'd0;
                3'd5: procedural=((px>>3)+(py>>2)) & 1 ? 8'd255:8'd0;
                default: procedural=8'd0;
            endcase
        end
    endfunction
    function [31:0] crc_byte;
        input [31:0] crc_i;
        input [7:0] byte_i;
        reg [31:0] c;
        integer bit_index;
        begin
            c=crc_i ^ {24'd0,byte_i};
            for (bit_index=0;bit_index<8;bit_index=bit_index+1)
                c=c[0] ? (c>>1)^32'hedb88320 : c>>1;
            crc_byte=c;
        end
    endfunction
    always @* begin
        tx_data=0;
        case (tx_index)
            16'd0:tx_data=8'h43; // CNY1
            16'd1:tx_data=8'h4e;
            16'd2:tx_data=8'h59;
            16'd3:tx_data=8'h31;
            16'd4:tx_data=8'd1;  // protocol version
            16'd5:tx_data=8'h80; // 640 little-endian
            16'd6:tx_data=8'h02;
            16'd7:tx_data=8'he0; // 480 little-endian
            16'd8:tx_data=8'h01;
            16'd9:tx_data={5'd0,selected_test};
            16'd10:tx_data=processing_cycles[7:0];
            16'd11:tx_data=processing_cycles[15:8];
            16'd12:tx_data=processing_cycles[23:16];
            16'd13:tx_data=processing_cycles[31:24];
            16'd14:tx_data=BYTES & 8'hff;
            16'd15:tx_data=(BYTES>>8) & 8'hff;
            16'd16:tx_data=(BYTES>>16) & 8'hff;
            16'd17:tx_data=(BYTES>>24) & 8'hff;
            16'd18:tx_data=PIXELS & 8'hff;
            16'd19:tx_data=(PIXELS>>8) & 8'hff;
            16'd20:tx_data=(PIXELS>>16) & 8'hff;
            16'd21:tx_data=(PIXELS>>24) & 8'hff;
            default:begin
                if (tx_index<HEADER_BYTES+BYTES) tx_data=edge_read_q;
                else tx_data=(~crc >> (8*(tx_index-(HEADER_BYTES+BYTES)))) & 8'hff;
            end
        endcase
    end
    always @(posedge clk100mhz) begin
        rom_q<=image_rom[image_addr];
        pattern_q<=procedural(selected_test,x,y);
        edge_read_q<=edge_mem[payload_addr];
        if (rst_n && out_hs && out_de && pixel_count<PIXELS && pixel_count[2:0]==7)
            edge_mem[pixel_count[18:3]]<={pack_shift[6:0],out_edge};
    end
    uart_tx_phase11 #(.CLKS_PER_BIT(UART_DIV)) u_uart (
        .clk(clk100mhz),.rst_n(rst_n),.valid_i(tx_valid),
        .data_i(tx_data),.ready_o(tx_ready),.tx_o(uart_tx_o));
    canny_block_adaptive_phase10_top #(.ENGINE_COUNT(1)) u_core (
        .clk(clk100mhz),.rst_n(rst_n),.per_frame_vsync(stream_vs),
        .per_frame_href(stream_hs),.per_frame_clken(stream_de),
        .per_img_y(stream_pixel),.mode_i(1'b1),
        .threshold_low_i(11'd50),.threshold_high_i(11'd100),
        .post_frame_vsync(out_vs),.post_frame_href(out_hs),
        .post_frame_clken(out_de),.post_img_bit(out_edge));
    assign led={error_flag,state==S_TX,state==S_DONE,state!=S_IDLE};

    // Keep board frame-memory addresses on synchronously reset registers.
    // The source ROM/output BRAM arrays themselves are never reset.
    always @(posedge clk100mhz) begin
        if (!rst_n) begin
            state<=S_IDLE;selected_test<=0;
            image_addr<=0;pixel_count<=0;payload_addr<=0;
            x<=0;y<=0;pre_count<=0;blank_count<=0;post_count<=0;end_count<=0;
            stream_vs<=0;stream_hs<=0;stream_de<=0;
            pack_shift<=0;cycles<=0;input_first_cycle<=0;
            first_output_cycle<=0;last_output_cycle<=0;processing_cycles<=0;
            input_seen<=0;output_seen<=0;frame_done<=0;error_flag<=0;
            tx_index<=0;crc<=32'hffffffff;
        end else begin
            cycles<=cycles+1'b1;
            stream_vs<=0;stream_hs<=0;stream_de<=0;
            if (stream_vs && stream_hs && stream_de && !input_seen) begin
                input_seen<=1;input_first_cycle<=cycles;
            end
            if (out_hs && out_de) begin
                if (!output_seen) begin
                    output_seen<=1;first_output_cycle<=cycles;
                end
                if (frame_done || pixel_count>=PIXELS) error_flag<=1;
                else begin
                    pack_shift<={pack_shift[6:0],out_edge};
                    pixel_count<=pixel_count+1'b1;
                    if (pixel_count==PIXELS-1) begin
                        frame_done<=1;last_output_cycle<=cycles;
                        processing_cycles<=cycles-input_first_cycle+1'b1;
                    end
                end
            end
            case (state)
                S_IDLE:if (start_pulse) begin
                    selected_test<=test_sel<=5 ? test_sel:3'd1;
                    image_addr<=0;pixel_count<=0;pack_shift<=0;
                    input_seen<=0;output_seen<=0;frame_done<=0;error_flag<=0;
                    crc<=32'hffffffff;tx_index<=0;
                    pre_count<=0;x<=0;y<=0;state<=S_PRE;
                end
                S_PRE:begin
                    if (pre_count==79) state<=S_ACTIVE;
                    else pre_count<=pre_count+1'b1;
                end
                S_ACTIVE:begin
                    stream_vs<=1;stream_hs<=1;stream_de<=1;
                    image_addr<=image_addr+1'b1;
                    if (x==WIDTH-1) begin
                        x<=0;blank_count<=0;state<=S_BLANK;
                    end else x<=x+1'b1;
                end
                S_BLANK:begin
                    stream_vs<=1;
                    if (blank_count==23) begin
                        if (y==HEIGHT-1) begin post_count<=0;state<=S_POST;end
                        else begin y<=y+1'b1;state<=S_ACTIVE;end
                    end else blank_count<=blank_count+1'b1;
                end
                S_POST:begin
                    stream_vs<=1;
                    if (post_count==127) begin end_count<=0;state<=S_END;end
                    else post_count<=post_count+1'b1;
                end
                S_END:begin
                    if (end_count==39) state<=S_WAIT;
                    else end_count<=end_count+1'b1;
                end
                S_WAIT:if (frame_done && !error_flag) state<=S_TX;
                S_TX:begin
                    if (tx_valid && tx_ready) begin
                        tx_index<=tx_index+1'b1;
                        if (tx_index>=HEADER_BYTES && tx_index<HEADER_BYTES+BYTES) begin
                            crc<=crc_byte(crc,edge_read_q);
                            payload_addr<=payload_addr+1'b1;
                        end
                    end
                    if (tx_index==TOTAL_BYTES && tx_ready) state<=S_DONE;
                end
                default:state<=S_DONE;
            endcase
        end
    end
`ifndef SYNTHESIS
    always @(posedge clk100mhz) if (rst_n) begin
        if (state==S_ACTIVE && image_addr>=PIXELS)
            $fatal(1,"image ROM overflow");
        if (out_hs && out_de && (^out_edge===1'bx))
            $fatal(1,"unknown valid output bit");
        if (state==S_TX && pixel_count!=PIXELS)
            $fatal(1,"UART before complete frame");
    end
`endif
endmodule
`default_nettype wire
