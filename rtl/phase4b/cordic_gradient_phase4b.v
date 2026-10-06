`default_nettype none
// 16-stage first-quadrant vectoring CORDIC for legal Sobel magnitudes 0..1020.
// Coordinates use Q12 pixels in signed 26-bit registers. The largest ideal
// gain-scaled coordinate is < 2376*4096 = 9,732,096, far below 2^25.
// Angle is signed degrees Q16. Direction is one-hot NMS orientation:
// 0001 horizontal, 0010 /, 0100 vertical, 1000 \ in image coordinates.
module cordic_gradient_phase4b #(
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
            reg signed [XY_W-1:0] x_reg;
            reg signed [ANGLE_W-1:0] angle_reg;
            wire signed [XY_W-1:0] x_shift = x[stage] >>> stage;
            wire signed [XY_W-1:0] y_shift = y[stage] >>> stage;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    x_reg <= {XY_W{1'b0}};
                    angle_reg <= {ANGLE_W{1'b0}};
                end else if (y[stage] >= 0) begin
                    x_reg <= x[stage] + y_shift;
                    angle_reg <= angle[stage] + atan_q16(stage);
                end else begin
                    x_reg <= x[stage] - y_shift;
                    angle_reg <= angle[stage] - atan_q16(stage);
                end
            end
            assign x[stage+1] = x_reg;
            assign angle[stage+1] = angle_reg;
            // The last stage's y is never consumed: only its x/angle are
            // gain-compensated and classified. Do not create a dead register.
            if (stage < CORDIC_ITERATIONS-1) begin: g_y
                reg signed [XY_W-1:0] y_reg;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        y_reg <= {XY_W{1'b0}};
                    else if (y[stage] >= 0)
                        y_reg <= y[stage] - x_shift;
                    else
                        y_reg <= y[stage] + x_shift;
                end
                assign y[stage+1] = y_reg;
            end else begin: g_last_y_unused
                assign y[stage+1] = {XY_W{1'b0}};
            end
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
    // Two post-vectoring registers break the old gain -> clamp -> threshold path.
    // Stage A captures the exact Phase-4 48-bit product, angle, quadrant, and
    // controls. Stage B performs the unchanged shift/clamp/direction mapping.
    localparam integer CORDIC_LATENCY = CORDIC_ITERATIONS + 2;
    reg signed [47:0] scaled_reg;
    reg signed [ANGLE_W-1:0] angle_post;
    reg zero_post, opposite_post, valid_post, vsync_post, href_post;
    wire signed [47:0] scaled_next =
        $signed(x[CORDIC_ITERATIONS]) * 48'sd39797;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scaled_reg <= 48'sd0;
            angle_post <= {ANGLE_W{1'b0}};
            zero_post <= 1'b0; opposite_post <= 1'b0;
            valid_post <= 1'b0; vsync_post <= 1'b0; href_post <= 1'b0;
        end else begin
            scaled_reg <= scaled_next;
            angle_post <= angle[CORDIC_ITERATIONS];
            zero_post <= zero_pipe[CORDIC_ITERATIONS-1];
            opposite_post <= opposite_pipe[CORDIC_ITERATIONS-1];
            valid_post <= valid_pipe[CORDIC_ITERATIONS-1];
            vsync_post <= vsync_pipe[CORDIC_ITERATIONS-1];
            href_post <= href_pipe[CORDIC_ITERATIONS-1];
        end
    end

    wire signed [47:0] magnitude_raw = scaled_reg >>> (XY_FRAC + 16);
    localparam signed [ANGLE_W-1:0] BOUND_22_5 = 24'sd1474560;
    localparam signed [ANGLE_W-1:0] BOUND_67_5 = 24'sd4423680;
    reg [MAG_W-1:0] magnitude_reg;
    reg [3:0] direction_reg;
    reg out_valid_reg, out_vsync_reg, out_href_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            magnitude_reg <= {MAG_W{1'b0}};
            direction_reg <= 4'b0001;
            out_valid_reg <= 1'b0; out_vsync_reg <= 1'b0;
            out_href_reg <= 1'b0;
        end else begin
            magnitude_reg <= zero_post ? {MAG_W{1'b0}} :
                             (magnitude_raw < 0) ? {MAG_W{1'b0}} :
                             (magnitude_raw > 2047) ? {MAG_W{1'b1}} :
                             magnitude_raw[MAG_W-1:0];
            direction_reg <= zero_post ? 4'b0001 :
                             (angle_post < BOUND_22_5) ? 4'b0001 :
                             (angle_post >= BOUND_67_5) ? 4'b0100 :
                             opposite_post ? 4'b0010 : 4'b1000;
            out_valid_reg <= valid_post;
            out_vsync_reg <= vsync_post;
            out_href_reg <= href_post;
        end
    end
    assign magnitude = magnitude_reg;
    assign direction = direction_reg;
    assign out_valid = out_valid_reg;
    assign out_vsync = out_vsync_reg;
    assign out_href = out_href_reg;
endmodule
`default_nettype wire
