`default_nettype none
// 16-stage first-quadrant vectoring CORDIC for legal Sobel magnitudes 0..1020.
// Coordinates use Q12 pixels in signed 26-bit registers. The largest ideal
// gain-scaled coordinate is < 2376*4096 = 9,732,096, far below 2^25.
// Angle is signed degrees Q16. Direction is one-hot NMS orientation:
// 0001 horizontal, 0010 /, 0100 vertical, 1000 \ in image coordinates.
module cordic_gradient_phase4 #(
    parameter integer CORDIC_ITERATIONS = 16,
    parameter integer XY_W = 26,
    parameter integer XY_FRAC = 12,
    parameter integer MAG_W = 11,
    parameter integer ANGLE_W = 24
) (
    input  wire clk,
    input  wire rst_n,
    input  wire [10:0] abs_gx,
    input  wire [10:0] abs_gy,
    input  wire sign_gx,
    input  wire sign_gy,
    input  wire in_vsync,
    input  wire in_href,
    input  wire in_valid,
    output wire [MAG_W-1:0] magnitude,
    output wire [3:0] direction,
    output wire out_vsync,
    output wire out_href,
    output wire out_valid
);
    // Q16 degrees, rounded atan(2^-i), i=0..15. All later constants nonzero.
    function signed [ANGLE_W-1:0] atan_q16;
        input integer idx;
        begin
            case (idx)
                 0: atan_q16 = 24'sd2949120;
                 1: atan_q16 = 24'sd1740967;
                 2: atan_q16 = 24'sd919879;
                 3: atan_q16 = 24'sd466945;
                 4: atan_q16 = 24'sd234379;
                 5: atan_q16 = 24'sd117304;
                 6: atan_q16 = 24'sd58666;
                 7: atan_q16 = 24'sd29335;
                 8: atan_q16 = 24'sd14668;
                 9: atan_q16 = 24'sd7334;
                10: atan_q16 = 24'sd3667;
                11: atan_q16 = 24'sd1833;
                12: atan_q16 = 24'sd917;
                13: atan_q16 = 24'sd458;
                14: atan_q16 = 24'sd229;
                15: atan_q16 = 24'sd115;
                default: atan_q16 = {ANGLE_W{1'b0}};
            endcase
        end
    endfunction

    wire signed [XY_W-1:0] x [0:CORDIC_ITERATIONS];
    wire signed [XY_W-1:0] y [0:CORDIC_ITERATIONS];
    wire signed [ANGLE_W-1:0] angle [0:CORDIC_ITERATIONS];
    assign x[0] = $signed({{(XY_W-11){1'b0}},abs_gx}) <<< XY_FRAC;
    assign y[0] = $signed({{(XY_W-11){1'b0}},abs_gy}) <<< XY_FRAC;
    assign angle[0] = {ANGLE_W{1'b0}};

    genvar stage;
    generate
        for (stage=0; stage<CORDIC_ITERATIONS; stage=stage+1) begin: g_stage
            reg signed [XY_W-1:0] x_reg, y_reg;
            reg signed [ANGLE_W-1:0] angle_reg;
            wire signed [XY_W-1:0] x_shift = x[stage] >>> stage;
            wire signed [XY_W-1:0] y_shift = y[stage] >>> stage;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    x_reg <= {XY_W{1'b0}};
                    y_reg <= {XY_W{1'b0}};
                    angle_reg <= {ANGLE_W{1'b0}};
                end else if (y[stage] >= 0) begin
                    x_reg <= x[stage] + y_shift;
                    y_reg <= y[stage] - x_shift;
                    angle_reg <= angle[stage] + atan_q16(stage);
                end else begin
                    x_reg <= x[stage] - y_shift;
                    y_reg <= y[stage] + x_shift;
                    angle_reg <= angle[stage] - atan_q16(stage);
                end
            end
            assign x[stage+1] = x_reg;
            assign y[stage+1] = y_reg;
            assign angle[stage+1] = angle_reg;
        end
    endgenerate

    reg [CORDIC_ITERATIONS-1:0] valid_pipe, vsync_pipe, href_pipe;
    reg [CORDIC_ITERATIONS-1:0] opposite_pipe, zero_pipe;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= {CORDIC_ITERATIONS{1'b0}};
            vsync_pipe <= {CORDIC_ITERATIONS{1'b0}};
            href_pipe <= {CORDIC_ITERATIONS{1'b0}};
            opposite_pipe <= {CORDIC_ITERATIONS{1'b0}};
            zero_pipe <= {CORDIC_ITERATIONS{1'b0}};
        end else begin
            valid_pipe <= (valid_pipe << 1) | in_valid;
            vsync_pipe <= (vsync_pipe << 1) | in_vsync;
            href_pipe <= (href_pipe << 1) | in_href;
            opposite_pipe <= (opposite_pipe << 1) | (sign_gx ^ sign_gy);
            zero_pipe <= (zero_pipe << 1) | ((abs_gx == 0) && (abs_gy == 0));
        end
    end
    assign out_valid = valid_pipe[CORDIC_ITERATIONS-1];
    assign out_vsync = vsync_pipe[CORDIC_ITERATIONS-1];
    assign out_href = href_pipe[CORDIC_ITERATIONS-1];

    // Gain compensation K^-1 = 39797/65536, rounded for 16 iterations.
    // 48-bit signed product is ample: 9,732,096*39,797 < 2^39.
    wire signed [47:0] scaled = $signed(x[CORDIC_ITERATIONS]) * 48'sd39797;
    wire signed [47:0] magnitude_raw = scaled >>> (XY_FRAC + 16);
    assign magnitude = zero_pipe[CORDIC_ITERATIONS-1] ? {MAG_W{1'b0}} :
                       (magnitude_raw < 0) ? {MAG_W{1'b0}} :
                       (magnitude_raw > 2047) ? {MAG_W{1'b1}} :
                       magnitude_raw[MAG_W-1:0];

    localparam signed [ANGLE_W-1:0] BOUND_22_5 = 24'sd1474560;
    localparam signed [ANGLE_W-1:0] BOUND_67_5 = 24'sd4423680;
    assign direction = zero_pipe[CORDIC_ITERATIONS-1] ? 4'b0001 :
                       (angle[CORDIC_ITERATIONS] < BOUND_22_5) ? 4'b0001 :
                       (angle[CORDIC_ITERATIONS] >= BOUND_67_5) ? 4'b0100 :
                       opposite_pipe[CORDIC_ITERATIONS-1] ? 4'b0010 : 4'b1000;
endmodule
`default_nettype wire
