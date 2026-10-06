`default_nettype none
// 8-N-1 transmitter. CLKS_PER_BIT=868 at 100 MHz gives ~115207 baud.
module uart_tx_phase11 #(
    parameter integer CLKS_PER_BIT=868
) (
    input wire clk,rst_n,
    input wire valid_i,
    input wire [7:0] data_i,
    output wire ready_o,
    output reg tx_o
);
    reg [9:0] shift;
    reg [3:0] bits_left;
    reg [9:0] div_count;
    reg busy;
    assign ready_o=!busy;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_o<=1;shift<=10'h3ff;bits_left<=0;
            div_count<=0;busy<=0;
        end else if (!busy) begin
            tx_o<=1;
            if (valid_i) begin
                shift<={1'b1,data_i,1'b0};
                bits_left<=10;
                div_count<=CLKS_PER_BIT-1;
                tx_o<=0;busy<=1;
            end
        end else if (div_count==0) begin
            shift<={1'b1,shift[9:1]};
            tx_o<=shift[1];
            div_count<=CLKS_PER_BIT-1;
            if (bits_left==1) begin
                bits_left<=0;busy<=0;tx_o<=1;
            end else bits_left<=bits_left-1'b1;
        end else div_count<=div_count-1'b1;
    end
`ifndef SYNTHESIS
    initial if (CLKS_PER_BIT<2 || CLKS_PER_BIT>1024)
        $fatal(1,"unsupported UART divider");
`endif
endmodule
`default_nettype wire
