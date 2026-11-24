module vga_controller (
    input  wire clk_pixel,
    input  wire rst_n,
    
    input  wire [4:0] head_x,       input  wire [4:0] head_y,
    input  wire [4:0] apple_good_x, input  wire [4:0] apple_good_y,
    input  wire [4:0] apple_bad_x,  input  wire [4:0] apple_bad_y,
    input  wire [6:0] snake_length,
    
    input  wire [499:0] body_x_flat,
    input  wire [499:0] body_y_flat,
    input  wire [15:0] score, // AHORA DE 16 BITS
    input  wire game_over,
    input  wire game_win,

    output wire hs, vs, de,
    output wire [7:0] r, g, b
);

    parameter H_VISIBLE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48, H_TOTAL = 800;
    parameter V_VISIBLE = 480, V_FRONT = 10, V_SYNC = 2, V_BACK = 33, V_TOTAL = 525;

    reg [9:0] h_cnt = 0; reg [9:0] v_cnt = 0;

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 0; v_cnt <= 0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0; v_cnt <= (v_cnt == V_TOTAL - 1) ? 0 : v_cnt + 1;
            end else h_cnt <= h_cnt + 1;
        end
    end

    assign hs = ~((h_cnt >= H_VISIBLE + H_FRONT) && (h_cnt < H_VISIBLE + H_FRONT + H_SYNC));
    assign vs = ~((v_cnt >= V_VISIBLE + V_FRONT) && (v_cnt < V_VISIBLE + V_FRONT + V_SYNC));
    assign de = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);

    // =========================================================
    // LÓGICA DEL MARCADOR DE PUNTOS (7 SEGMENTOS)
    // =========================================================
    function [6:0] hex2seg;
        input [3:0] num;
        case(num)
            4'd0: hex2seg = 7'b1111110;
            4'd1: hex2seg = 7'b0110000;
            4'd2: hex2seg = 7'b1101101;
            4'd3: hex2seg = 7'b1111001;
            4'd4: hex2seg = 7'b0110011;
            4'd5: hex2seg = 7'b1011011;
            4'd6: hex2seg = 7'b1011111;
            4'd7: hex2seg = 7'b1110000;
            4'd8: hex2seg = 7'b1111111;
            4'd9: hex2seg = 7'b1111011;
            default: hex2seg = 7'b0000000;
        endcase
    endfunction

    // 4 DÍGITOS
    wire [3:0] d3 = score[15:12]; // Miles
    wire [3:0] d2 = score[11:8];  // Centenas
    wire [3:0] d1 = score[7:4];   // Decenas
    wire [3:0] d0 = score[3:0];   // Unidades

    wire [6:0] seg3 = hex2seg(d3);
    wire [6:0] seg2 = hex2seg(d2);
    wire [6:0] seg1 = hex2seg(d1);
    wire [6:0] seg0 = hex2seg(d0);

    // CAJAS DE POSICIÓN
    wire in_digit_3 = (h_cnt >= 450 && h_cnt < 480 && v_cnt >= 16 && v_cnt < 56);
    wire in_digit_2 = (h_cnt >= 490 && h_cnt < 520 && v_cnt >= 16 && v_cnt < 56);
    wire in_digit_1 = (h_cnt >= 530 && h_cnt < 560 && v_cnt >= 16 && v_cnt < 56);
    wire in_digit_0 = (h_cnt >= 570 && h_cnt < 600 && v_cnt >= 16 && v_cnt < 56);

    wire [4:0] lx = in_digit_3 ? (h_cnt - 450) :
                    in_digit_2 ? (h_cnt - 490) :
                    in_digit_1 ? (h_cnt - 530) :
                    in_digit_0 ? (h_cnt - 570) : 5'd0;
    wire [5:0] ly = (v_cnt - 16);

    wire [6:0] active_seg = in_digit_3 ? seg3 :
                            in_digit_2 ? seg2 :
                            in_digit_1 ? seg1 :
                            in_digit_0 ? seg0 : 7'b0;

    reg [7:0] red, green, blue;
    reg is_body;
    reg is_score;
    integer k;

    always @(*) begin
        // 1. Cuerpo
        is_body = 1'b0;
        for (k = 0; k < 100; k = k + 1) begin 
            if (k < snake_length) begin
                if (h_cnt >= (body_x_flat[k*5 +: 5] * 64) && h_cnt < ((body_x_flat[k*5 +: 5] + 1) * 64) && 
                    v_cnt >= (body_y_flat[k*5 +: 5] * 48) && v_cnt < ((body_y_flat[k*5 +: 5] + 1) * 48)) begin
                    is_body = 1'b1;
                end
            end
        end

        // 2. Marcador
        is_score = 1'b0;
        if (in_digit_3 || in_digit_2 || in_digit_1 || in_digit_0) begin
            if (active_seg[6] && ly < 6) is_score = 1'b1; 
            if (active_seg[5] && lx >= 24 && ly < 20) is_score = 1'b1; 
            if (active_seg[4] && lx >= 24 && ly >= 20) is_score = 1'b1; 
            if (active_seg[3] && ly >= 34) is_score = 1'b1; 
            if (active_seg[2] && lx < 6 && ly >= 20) is_score = 1'b1; 
            if (active_seg[1] && lx < 6 && ly < 20) is_score = 1'b1; 
            if (active_seg[0] && ly >= 17 && ly < 23) is_score = 1'b1; 
        end

        // 3. Cadena Estricta
        if (!de) begin
            {red, green, blue} = {8'h00, 8'h00, 8'h00};
        end else begin
            
            // --- LETRAS YOU LOSE ---
            if (game_over && h_cnt >= 222 && h_cnt < 229 && v_cnt >= 200 && v_cnt < 240) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 229 && h_cnt < 236 && v_cnt >= 240 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 236 && h_cnt < 243 && v_cnt >= 200 && v_cnt < 240) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 247 && h_cnt < 254 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 254 && h_cnt < 261 && v_cnt >= 200 && v_cnt < 207) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 254 && h_cnt < 261 && v_cnt >= 273 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 261 && h_cnt < 268 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 272 && h_cnt < 279 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 279 && h_cnt < 286 && v_cnt >= 273 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 286 && h_cnt < 293 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 322 && h_cnt < 329 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 329 && h_cnt < 343 && v_cnt >= 273 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 347 && h_cnt < 354 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 354 && h_cnt < 361 && v_cnt >= 200 && v_cnt < 207) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 354 && h_cnt < 361 && v_cnt >= 273 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 361 && h_cnt < 368 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 372 && h_cnt < 393 && v_cnt >= 200 && v_cnt < 207) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 372 && h_cnt < 379 && v_cnt >= 207 && v_cnt < 236) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 372 && h_cnt < 393 && v_cnt >= 236 && v_cnt < 243) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 386 && h_cnt < 393 && v_cnt >= 243 && v_cnt < 273) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 372 && h_cnt < 393 && v_cnt >= 273 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 397 && h_cnt < 418 && v_cnt >= 200 && v_cnt < 207) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 397 && h_cnt < 418 && v_cnt >= 236 && v_cnt < 243) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 397 && h_cnt < 418 && v_cnt >= 273 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            else if (game_over && h_cnt >= 397 && h_cnt < 404 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00};
            end
            // FONDO DERROTA
            else if (game_over && h_cnt >= 220 && h_cnt < 420 && v_cnt >= 190 && v_cnt < 290) begin
                {red, green, blue} = {8'hFF, 8'h00, 8'h00}; 
            end
            
            // --- LETRAS YOU WIN ---
            else if (game_win && h_cnt >= 222 && h_cnt < 229 && v_cnt >= 200 && v_cnt < 240) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 229 && h_cnt < 236 && v_cnt >= 240 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 236 && h_cnt < 243 && v_cnt >= 200 && v_cnt < 240) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 247 && h_cnt < 254 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 254 && h_cnt < 261 && v_cnt >= 200 && v_cnt < 207) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 254 && h_cnt < 261 && v_cnt >= 273 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 261 && h_cnt < 268 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 272 && h_cnt < 279 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 279 && h_cnt < 286 && v_cnt >= 273 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 286 && h_cnt < 293 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 411 && h_cnt < 418 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 404 && h_cnt < 411 && v_cnt >= 252 && v_cnt < 266) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 397 && h_cnt < 404 && v_cnt >= 238 && v_cnt < 252) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 390 && h_cnt < 397 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 379 && h_cnt < 386 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 368 && h_cnt < 375 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 340 && h_cnt < 375 && v_cnt >= 273 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 340 && h_cnt < 347 && v_cnt >= 200 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            else if (game_win && h_cnt >= 354 && h_cnt < 361 && v_cnt >= 244 && v_cnt < 280) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF};
            end
            // FONDO VICTORIA
            else if (game_win && h_cnt >= 220 && h_cnt < 420 && v_cnt >= 190 && v_cnt < 290) begin
                {red, green, blue} = {8'hFF, 8'hD7, 8'h00}; 
            end
            
            // --- MARCADOR 7 SEGMENTOS BLANCO ---
            else if (is_score) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'hFF}; 
            end
            // FONDO NEGRO DEL MARCADOR (Lo alargué a la izquierda para que quepa el dígito de miles)
            else if (h_cnt >= 430 && h_cnt < 620 && v_cnt >= 10 && v_cnt < 62) begin
                {red, green, blue} = {8'h00, 8'h00, 8'h00}; 
            end
            
            // --- DIBUJO DEL JUEGO NORMAL ---
            else if (h_cnt >= (head_x * 64) && h_cnt < ((head_x + 1) * 64) && 
                     v_cnt >= (head_y * 48) && v_cnt < ((head_y + 1) * 48)) begin
                {red, green, blue} = {8'h7D, 8'hB5, 8'hFA}; 
            end
            else if (is_body) begin
                {red, green, blue} = {8'h00, 8'h00, 8'hFF}; 
            end
            else if (h_cnt >= (apple_good_x * 64) && h_cnt < ((apple_good_x + 1) * 64) && 
                     v_cnt >= (apple_good_y * 48) && v_cnt < ((apple_good_y + 1) * 48)) begin
                {red, green, blue} = {8'hFF, 8'hFF, 8'h00}; 
            end
            else if (h_cnt >= (apple_bad_x * 64) && h_cnt < ((apple_bad_x + 1) * 64) && 
                     v_cnt >= (apple_bad_y * 48) && v_cnt < ((apple_bad_y + 1) * 48)) begin
                {red, green, blue} = {8'hFF, 8'h00, 8'h00}; 
            end
            
            // --- FONDO CUADRICULADO ---
            else if (((h_cnt / 64) % 2) == ((v_cnt / 48) % 2)) begin
                {red, green, blue} = {8'h00, 8'h80, 8'h00};
            end else begin
                {red, green, blue} = {8'h00, 8'hFF, 8'h80};
            end
        end
    end
    
    assign r = red; assign g = green; assign b = blue;
endmodule
