module canny_doubleThreshold_phase5b#(
    parameter DATA_WIDTH = 2,
    parameter DATA_DEPTH = 640
)(
	input			                    clk                 ,
	input			                    rst_s               ,
    
	input			                    pre_frame_vsync     ,
	input			                    pre_frame_href      ,
	input			                    pre_frame_clken     ,
	input      [DATA_WIDTH - 1 : 0]     max_g               ,
    
	output		                        post_frame_vsync    ,
	output		                        post_frame_href     ,
	output		                        post_frame_clken    ,
	output      reg                     canny_out           
);

wire    [DATA_WIDTH - 1 : 0]   mag1_1;
wire    [DATA_WIDTH - 1 : 0]   mag1_2;
wire    [DATA_WIDTH - 1 : 0]   mag1_3;
wire    [DATA_WIDTH - 1 : 0]   mag2_1;
wire    [DATA_WIDTH - 1 : 0]   mag2_2;
wire    [DATA_WIDTH - 1 : 0]   mag2_3;
wire    [DATA_WIDTH - 1 : 0]   mag3_1;
wire    [DATA_WIDTH - 1 : 0]   mag3_2;
wire    [DATA_WIDTH - 1 : 0]   mag3_3;
    
wire        doubleThreshold_vsync   ;
wire        doubleThreshold_href    ;
wire        doubleThreshold_clken   ;    
wire        high_low                ;
wire        search                  ;


//Ë«ãÐÖµ£¬8Á¬Í¨ÓòÁ¬½ÓÏñËØ
matrix_generate_3x3_phase5b #(
	.DATA_WIDTH         (DATA_WIDTH             ),
	.DATA_DEPTH         (DATA_DEPTH             )
)u_matrix_generate_3x3_phase5b(     
    .clk                (clk                    ), 
    .rst_n              (rst_s                  ),

    //´¦ÀíÇ°Í¼ÏñÊý¾Ý        
    .per_frame_vsync    (pre_frame_vsync        ),
    .per_frame_href     (pre_frame_href         ), 
    .per_frame_clken    (pre_frame_clken        ),
    .per_img_y          (max_g                  ),
    
    //´¦ÀíºóµÄÍ¼ÏñÊý¾Ý
    .matrix_frame_vsync (doubleThreshold_vsync  ),
    .matrix_frame_href  (doubleThreshold_href   ),
    .matrix_frame_clken (doubleThreshold_clken  ),
    .matrix_p11         (mag1_1                 ),    
    .matrix_p12         (mag1_2                 ),    
    .matrix_p13         (mag1_3                 ),
    .matrix_p21         (mag2_1                 ),    
    .matrix_p22         (mag2_2                 ),    
    .matrix_p23         (mag2_3                 ),
    .matrix_p31         (mag3_1                 ),    
    .matrix_p32         (mag3_2                 ),    
    .matrix_p33         (mag3_3                 )
);

assign search = mag1_1[1] | mag1_2[1] | mag1_3[1] | mag2_1[1] | mag2_2[1] | mag2_3[1] 
| mag3_1[1] | mag3_2[1] | mag3_3[1];//ËÑÑ°Ä¿±êÏñËØÖÜ±ßÊÇ·ñ°üº¬ÌÝ¶ÈÖµ´óÓÚ¸ßãÐÖµµÄµã£¬µ±È»×ÔÉíÊÇ¸ßÓÚµÄ»°£¬ÄÇÃ´¿Ï¶¨Îª1  
assign high_low = mag2_2[1] | mag2_2[0];//ÅÅ³ýÐ¡ÓÚµÍãÐÖµµÄµã

//¶Ô hs vs de ½øÐÐÊÊµ±µÄÑÓ³Ù£¬Æ¥ÅäÊ±ÖÓ
reg         doubleThreshold_vsync_d1    ;
reg         doubleThreshold_href_d1     ;
reg         doubleThreshold_clken_d1    ;

always@(posedge clk) begin
    if (!rst_s) begin
        doubleThreshold_vsync_d1         <= 0 ;
        doubleThreshold_href_d1          <= 0 ;
        doubleThreshold_clken_d1         <= 0 ;
    end
    else begin
        doubleThreshold_vsync_d1         <= doubleThreshold_vsync   ;
        doubleThreshold_href_d1          <= doubleThreshold_href    ;
        doubleThreshold_clken_d1         <= doubleThreshold_clken   ;
    end
end

always @(posedge clk) begin
    if(!rst_s)
        canny_out <= 1'b0;
    else if(high_low)
        canny_out <= (search) ? 1'b1 : 1'b0;
    else
        canny_out <= 1'b0;
end

assign post_frame_vsync = doubleThreshold_vsync_d1 ;
assign post_frame_href  = doubleThreshold_href_d1  ;
assign post_frame_clken = doubleThreshold_clken_d1 ;

    
endmodule

