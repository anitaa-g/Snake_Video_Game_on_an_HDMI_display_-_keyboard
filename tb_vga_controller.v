//Creado por IA
`timescale 1ns / 1ps

module tb_vga_controller;

    localparam CLK_HALF = 20; // Reloj de 25 MHz (periodo 40 ns)

    reg          clk_pixel;
    reg          rst_n;
    reg  [4:0]   head_x, head_y;
    reg  [4:0]   apple_good_x, apple_good_y;
    reg  [4:0]   apple_bad_x, apple_bad_y;
    reg  [6:0]   snake_length;
    reg  [499:0] body_x_flat;
    reg  [499:0] body_y_flat;
    reg  [15:0]  score;
    reg          game_over;
    reg          game_win;

    wire         hs, vs, de;
    wire [7:0]   r, g, b;

    integer errors = 0;

    vga_controller dut (
        .clk_pixel    (clk_pixel),
        .rst_n        (rst_n),
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
        .game_win     (game_win),
        .hs           (hs),
        .vs           (vs),
        .de           (de),
        .r            (r),
        .g            (g),
        .b            (b)
    );

    initial begin
        clk_pixel = 1'b0;
        forever #CLK_HALF clk_pixel = ~clk_pixel;
    end

    task clear_inputs;
        begin
            head_x = 5'd0; head_y = 5'd0;
            apple_good_x = 5'd2; apple_good_y = 5'd2;
            apple_bad_x = 5'd4; apple_bad_y = 5'd4;
            snake_length = 7'd0;
            body_x_flat = 500'd0;
            body_y_flat = 500'd0;
            score = 16'h0000;
            game_over = 1'b0;
            game_win = 1'b0;
        end
    endtask

    task wait_for_hv;
        input [9:0] target_h;
        input [9:0] target_v;
        begin
            @(posedge clk_pixel);
            #1;
            while (dut.v_cnt !== target_v || dut.h_cnt !== target_h) begin
                @(posedge clk_pixel);
                #1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_vga_controller.vcd");
        $dumpvars(1, tb_vga_controller);

        clear_inputs();
        rst_n = 1'b0;
        @(posedge clk_pixel);
        #1;

        // 1. Reset activo -> contadores en 0
        if (dut.h_cnt !== 10'd0 || dut.v_cnt !== 10'd0) begin
            $display("[ERROR] Contadores no en 0 durante reset (h=%0d, v=%0d).", dut.h_cnt, dut.v_cnt);
            errors = errors + 1;
        end

        @(negedge clk_pixel);
        rst_n = 1'b1;

        // 2. Cabeza (0,0), comida (1,0) y veneno (2,0) en linea 0
        @(negedge clk_pixel);
        score = 16'h1234;
        head_x = 5'd0; head_y = 5'd0;
        apple_good_x = 5'd1; apple_good_y = 5'd0;
        apple_bad_x = 5'd2; apple_bad_y = 5'd0;

        wait_for_hv(10'd10, 10'd0);
        if ({r, g, b} !== 24'h7DB5FA) begin
            $display("[ERROR] Color cabeza incorrecto en (10,0): %h", {r, g, b});
            errors = errors + 1;
        end

        wait_for_hv(10'd70, 10'd0);
        if ({r, g, b} !== 24'hFFFF00) begin
            $display("[ERROR] Color comida amarilla incorrecto en (70,0): %h", {r, g, b});
            errors = errors + 1;
        end

        wait_for_hv(10'd130, 10'd0);
        if ({r, g, b} !== 24'hFF0000) begin
            $display("[ERROR] Color veneno rojo incorrecto en (130,0): %h", {r, g, b});
            errors = errors + 1;
        end

        // 3. Borde visible h=639 (de=1), blanking h=640 (de=0, RGB=0) y HSYNC h=656 (hs=0)
        wait_for_hv(10'd639, 10'd0);
        if (de !== 1'b1) begin
            $display("[ERROR] Esperado de=1 en h=639 (de=%b).", de);
            errors = errors + 1;
        end

        wait_for_hv(10'd640, 10'd0);
        if (de !== 1'b0 || ({r, g, b} !== 24'h000000)) begin
            $display("[ERROR] Esperado de=0 y RGB=0 en h=640 (de=%b, rgb=%h).", de, {r, g, b});
            errors = errors + 1;
        end

        wait_for_hv(10'd656, 10'd0);
        if (hs !== 1'b0) begin
            $display("[ERROR] Esperado hs=0 en h=656 (hs=%b).", hs);
            errors = errors + 1;
        end

        // 4. Fin de linea 0 (h=799) -> siguiente ciclo debe dar h=0, v=1
        wait_for_hv(10'd799, 10'd0);
        @(posedge clk_pixel);
        #1;
        if (dut.h_cnt !== 10'd0 || dut.v_cnt !== 10'd1) begin
            $display("[ERROR] No avanzo correctamente a v_cnt=1 (h=%0d, v=%0d).", dut.h_cnt, dut.v_cnt);
            errors = errors + 1;
        end

        // 5. Prioridad de GAME OVER (YOU LOSE) sobre elementos del juego
        @(negedge clk_pixel);
        game_over = 1'b1;
        head_x = 5'd3; head_y = 5'd4; // Coordenada (225, 205) esta en celda (3, 4)
        #1;
        wait_for_hv(10'd225, 10'd205);
        if ({r, g, b} !== 24'hFFFF00) begin
            $display("[ERROR] Prioridad GAME OVER (letra) fallo: %h", {r, g, b});
            errors = errors + 1;
        end

        $display("========================================");
        if (errors == 0)
            $display("RESULTADO: TB_VGA_CONTROLLER PASO TODAS LAS PRUEBAS.");
        else
            $display("RESULTADO: %0d ERRORES EN TB_VGA_CONTROLLER.", errors);
        $display("========================================");
        $fflush;
        $finish;
    end

endmodule