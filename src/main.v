module top_module (
    input  clk_27m,      
    input  rst_n,        
    input  uart_rx_pin,  
    
    output       O_tmds_clk_p,
    output       O_tmds_clk_n,
    output [2:0] O_tmds_data_p,
    output [2:0] O_tmds_data_n
);

    wire clk_serial; wire clk_pixel;  
    wire vs, hs, de; wire [7:0] r, g, b; 

    Gowin_rPLL pll_inst (.clkout(clk_serial), .clkin(clk_27m));

    CLKDIV u_clkdiv (
        .RESETN(rst_n),
        .HCLKIN(clk_serial), 
        .CLKOUT(clk_pixel),  
        .CALIB(1'b0)
    );
    defparam u_clkdiv.DIV_MODE = "5";
    defparam u_clkdiv.GSREN = "false";

    wire [7:0] rx_data; wire rx_valid;
    
    uart_rx uart_inst (
        .clk(clk_27m),
        .rst_n(rst_n),
        .rx(uart_rx_pin),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    wire [4:0] head_x, head_y;
    wire [4:0] apple_good_x, apple_good_y;
    wire [4:0] apple_bad_x, apple_bad_y;
    wire [6:0] snake_length;
    
    wire [499:0] body_x_flat;
    wire [499:0] body_y_flat;
    wire game_over;
    wire game_win;
    wire [15:0] score;

    snake_logic logic_inst (
        .clk_pixel(clk_pixel),
        .rst_n(rst_n),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .head_x(head_x), .head_y(head_y),
        .apple_good_x(apple_good_x), .apple_good_y(apple_good_y),
        .apple_bad_x(apple_bad_x), .apple_bad_y(apple_bad_y),
        .snake_length(snake_length),
        
        .body_x_flat(body_x_flat), 
        .body_y_flat(body_y_flat),
        .score(score),
        .game_over(game_over),
        .game_win(game_win)
    );

    vga_controller vga_inst (
        .clk_pixel(clk_pixel),
        .rst_n(rst_n),
        .head_x(head_x), .head_y(head_y),
        .apple_good_x(apple_good_x), .apple_good_y(apple_good_y),
        .apple_bad_x(apple_bad_x), .apple_bad_y(apple_bad_y),
        .snake_length(snake_length),
        
        .body_x_flat(body_x_flat), 
        .body_y_flat(body_y_flat),
        .score(score),
        .game_over(game_over),
        .game_win(game_win),
        
        .hs(hs), .vs(vs), .de(de),
        .r(r), .g(g), .b(b)
    );

    DVI_TX_Top dvi_tx_inst (
        .I_rst_n(rst_n), 
        .I_serial_clk(clk_serial),
        .I_rgb_clk(clk_pixel),     
        .I_rgb_vs(vs),             
        .I_rgb_hs(hs),             
        .I_rgb_de(de),             
        .I_rgb_r(r),               
        .I_rgb_g(g),               
        .I_rgb_b(b),               
        .O_tmds_clk_p(O_tmds_clk_p),     
        .O_tmds_clk_n(O_tmds_clk_n),     
        .O_tmds_data_p(O_tmds_data_p),   
        .O_tmds_data_n(O_tmds_data_n)    
    );

endmodule
