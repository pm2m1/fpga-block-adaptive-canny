module  matrix_generate_3x3_phase5b#(
    parameter DATA_WIDTH = 8,
    parameter DATA_DEPTH = 640
)
(
    input                           clk,  
    input                           rst_n,

    input                           per_frame_vsync,
    input                           per_frame_href,
    input                           per_frame_clken,
    input      [DATA_WIDTH - 1 :0]  per_img_y,
    
    output                          matrix_frame_vsync,
    output                          matrix_frame_href,
    output                          matrix_frame_clken,
    output reg [DATA_WIDTH - 1 :0]  matrix_p11,
    output reg [DATA_WIDTH - 1 :0]  matrix_p12, 
    output reg [DATA_WIDTH - 1 :0]  matrix_p13,
    output reg [DATA_WIDTH - 1 :0]  matrix_p21, 
    output reg [DATA_WIDTH - 1 :0]  matrix_p22, 
    output reg [DATA_WIDTH - 1 :0]  matrix_p23,
    output reg [DATA_WIDTH - 1 :0]  matrix_p31, 
    output reg [DATA_WIDTH - 1 :0]  matrix_p32, 
    output reg [DATA_WIDTH - 1 :0]  matrix_p33
);

//wire define
wire    [DATA_WIDTH - 1 : 0]    row1_data;  
wire    [DATA_WIDTH - 1 : 0]    row2_data;  
wire    [DATA_WIDTH - 1 : 0]    row3_data;  
wire                            read_frame_href;
wire                            read_frame_clken;
reg [1:0] lines_seen;
reg frame_vsync_d;
reg frame_href_d;
wire [DATA_WIDTH-1:0] row1_current = (lines_seen >= 2'd3) ? row1_data : {DATA_WIDTH{1'b0}};
wire [DATA_WIDTH-1:0] row2_current = (lines_seen >= 2'd2) ? row2_data : {DATA_WIDTH{1'b0}};

// Counts current-frame lines only; RAM contents/pointers are never cleared.
// The first active line sees both old rows as zero; the second sees row1 as zero.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lines_seen <= 2'd0;
        frame_vsync_d <= 1'b0;
        frame_href_d <= 1'b0;
    end else begin
        frame_vsync_d <= per_frame_vsync;
        frame_href_d <= per_frame_href;
        if (per_frame_vsync && !frame_vsync_d)
            // The protocol may raise VSYNC and HREF on the same first pixel.
            lines_seen <= per_frame_href ? 2'd1 : 2'd0;
        else if (per_frame_vsync && per_frame_href && !frame_href_d && lines_seen != 2'd3)
            lines_seen <= lines_seen + 2'd1;
    end
end

//reg define
reg     [1:0]                   per_frame_vsync_r;
reg     [1:0]                   per_frame_href_r;
reg     [1:0]                   per_frame_clken_r;

//*****************************************************
//**                    main code
//*****************************************************

assign read_frame_href    = per_frame_href_r[0] ;
assign read_frame_clken   = per_frame_clken_r[0];
assign matrix_frame_vsync = per_frame_vsync_r[1];
assign matrix_frame_href  = per_frame_href_r[1] ;
assign matrix_frame_clken = per_frame_clken_r[1];


one_column_ram #(
    .DATA_WIDTH(DATA_WIDTH),
    .DATA_DEPTH(DATA_DEPTH)
)u_one_column_ram(
    .clock      (clk),   
    .clken      (per_frame_clken),
    .shiftin    (per_img_y),

    .taps0x     (row3_data),
    .taps1x     (row2_data),
    .taps2x     (row1_data)
);

//½«Í¬²½ÐÅºÅÑÓ³ÙÁ½ÅÄ£¬ÓÃÓÚÍ¬²½»¯´¦Àí
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        per_frame_vsync_r <= 0;
        per_frame_href_r  <= 0;
        per_frame_clken_r <= 0;
    end
    else begin
        per_frame_vsync_r <= { per_frame_vsync_r[0], per_frame_vsync };
        per_frame_href_r  <= { per_frame_href_r[0],  per_frame_href  };
        per_frame_clken_r <= { per_frame_clken_r[0], per_frame_clken };
    end
end

//ÔÚÍ¬²½´¦ÀíºóµÄ¿ØÖÆÐÅºÅÏÂ£¬Êä³öÍ¼Ïñ¾ØÕó
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        {matrix_p11, matrix_p12, matrix_p13} <= 24'h0;
        {matrix_p21, matrix_p22, matrix_p23} <= 24'h0;
        {matrix_p31, matrix_p32, matrix_p33} <= 24'h0;
    end
    else if(read_frame_href) begin
        if(read_frame_clken) begin
            {matrix_p11, matrix_p12, matrix_p13} <= {matrix_p12, matrix_p13, row1_current};
            {matrix_p21, matrix_p22, matrix_p23} <= {matrix_p22, matrix_p23, row2_current};
            {matrix_p31, matrix_p32, matrix_p33} <= {matrix_p32, matrix_p33, row3_data};
        end
        else begin
            {matrix_p11, matrix_p12, matrix_p13} <= {matrix_p11, matrix_p12, matrix_p13};
            {matrix_p21, matrix_p22, matrix_p23} <= {matrix_p21, matrix_p22, matrix_p23};
            {matrix_p31, matrix_p32, matrix_p33} <= {matrix_p31, matrix_p32, matrix_p33};
        end
    end
    else begin
        {matrix_p11, matrix_p12, matrix_p13} <= 24'h0;
        {matrix_p21, matrix_p22, matrix_p23} <= 24'h0;
        {matrix_p31, matrix_p32, matrix_p33} <= 24'h0;
    end
end

endmodule 
