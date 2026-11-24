`timescale 1ns / 1ps

module tb_snake_logic;

    localparam CLK_HALF = 20; // Reloj de 25 MHz (40 ns periodo)

    reg          clk_pixel;
    reg          rst_n;
    reg  [7:0]   rx_data;
    reg          rx_valid;

    wire [4:0]   head_x, head_y;
    wire [4:0]   apple_good_x, apple_good_y;
    wire [4:0]   apple_bad_x, apple_bad_y;
    wire [6:0]   snake_length;
    wire [499:0] body_x_flat;
    wire [499:0] body_y_flat;
    wire [15:0]  score;
    wire         game_over;
    wire         game_win;

    reg  [4:0]   target_bx1, target_by1;
    integer      errors = 0;

    snake_logic dut (
        .clk_pixel    (clk_pixel),
        .rst_n        (rst_n),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .head_x       (head_x),
        .head_y       (head_y),
        .apple_good_x (apple_good_x),
        .apple_good_y (apple_good_y),
        .apple_bad_x  (apple_bad_x),
        .apple_bad_y  (apple_bad_y),
        .snake_length (snake_length),
        .body_x_flat  (body_x_flat),
        .body_y_flat  (body_y_flat),
        .score        (score),
        .game_over    (game_over),
        .game_win     (game_win)
    );

    initial begin
        clk_pixel = 1'b0;
        forever #CLK_HALF clk_pixel = ~clk_pixel;
    end

    // Envia un pulso rx_valid de 1 ciclo de reloj
    task send_key;
        input [7:0] ascii_code;
        begin
            @(negedge clk_pixel);
            rx_data  = ascii_code;
            rx_valid = 1'b1;
            @(posedge clk_pixel);
            @(negedge clk_pixel);
            rx_valid = 1'b0;
        end
    endtask

    // Dispara un move_tick en el siguiente flanco de subida acelerando tick_cnt
    task trigger_move_tick;
        begin
            @(negedge clk_pixel);
            force dut.tick_cnt = 23'd6_250_000;
            @(posedge clk_pixel);
            #1;
            release dut.tick_cnt;
        end
    endtask

    initial begin
        $display("[INFO] Iniciando tb_snake_logic...");
        $dumpfile("tb_snake_logic.vcd");
        $dumpvars(1, tb_snake_logic);

        // 1. Reset inicial
        rst_n    = 1'b0;
        rx_data  = 8'h00;
        rx_valid = 1'b0;
        @(posedge clk_pixel);
        #1;

        if (head_x !== 5'd5 || head_y !== 5'd2 || snake_length !== 7'd3 ||
            score !== 16'h0000 || game_over !== 1'b0 || game_win !== 1'b0) begin
            $display("[ERROR] Valores tras reset incorrectos.");
            errors = errors + 1;
        end

        @(negedge clk_pixel);
        rst_n = 1'b1;

        // 2. Corner Case: Giro invalido de 180 grados (actual_dir=RIGHT, intentar 'a' LEFT)
        send_key(8'h61); // 'a'
        if (dut.dir_state === 2'b10) begin
            $display("[ERROR] Giro de 180 grados (RIGHT -> LEFT) no fue bloqueado.");
            errors = errors + 1;
        end

        // Giro valido hacia arriba ('w' = 0x77) y paso con move_tick
        send_key(8'h77); // 'w' (UP)
        trigger_move_tick();
        if (head_x !== 5'd5 || head_y !== 5'd1) begin
            $display("[ERROR] Movimiento UP fallo: esperado (5,1), obtenido (%0d,%0d).", head_x, head_y);
            errors = errors + 1;
        end

        // 3. Corner Case: Wrap-around en borde superior (y=0 -> y=9 con UP)
        @(negedge clk_pixel);
        force dut.head_y = 5'd0;
        @(posedge clk_pixel);
        #1;
        release dut.head_y;

        trigger_move_tick();
        if (head_y !== 5'd9) begin
            $display("[ERROR] Wrap-around UP (0->9) fallo: head_y=%0d", head_y);
            errors = errors + 1;
        end

        // 4. Corner Case: Comer comida buena (+10 BCD y +1 longitud)
        @(negedge clk_pixel);
        force dut.head_x = 5'd7;
        force dut.head_y = 5'd7;
        @(posedge clk_pixel);
        #1;
        release dut.head_x;
        release dut.head_y;

        trigger_move_tick();
        if (score !== 16'h0010 || snake_length !== 7'd4) begin
            $display("[ERROR] Comer comida buena fallo: score=%h, len=%0d", score, snake_length);
            errors = errors + 1;
        end

        // 5. Corner Case: Comer veneno (-5 BCD y -1 longitud)
        @(negedge clk_pixel);
        force dut.head_x = apple_bad_x;
        force dut.head_y = apple_bad_y;
        @(posedge clk_pixel);
        #1;
        release dut.head_x;
        release dut.head_y;

        trigger_move_tick();
        if (score !== 16'h0005 || snake_length !== 7'd3) begin
            $display("[ERROR] Comer veneno fallo: score=%h, len=%0d", score, snake_length);
            errors = errors + 1;
        end

        // 6. Corner Case: Colision con el propio cuerpo -> game_over = 1
        // Primero avanzamos dos pasos para poblar body_x[1] y body_y[1]
        trigger_move_tick();
        trigger_move_tick();
        target_bx1 = body_x_flat[1*5 +: 5];
        target_by1 = body_y_flat[1*5 +: 5];

        // Colocamos la cabeza sobre body[1] y disparamos move_tick para evaluar self_collision
        @(negedge clk_pixel);
        force dut.head_x = target_bx1;
        force dut.head_y = target_by1;
        @(posedge clk_pixel);
        #1;
        release dut.head_x;
        release dut.head_y;

        trigger_move_tick();
        if (game_over !== 1'b1) begin
            $display("[ERROR] Colision consigo mismo no activo game_over (head=(%0d,%0d), body1=(%0d,%0d)).",
                     head_x, head_y, target_bx1, target_by1);
            errors = errors + 1;
        end

        $display("========================================");
        if (errors == 0)
            $display("RESULTADO: TB_SNAKE_LOGIC PASO TODAS LAS PRUEBAS.");
        else
            $display("RESULTADO: %0d ERRORES EN TB_SNAKE_LOGIC.", errors);
        $display("========================================");
        $finish;
    end

endmodule