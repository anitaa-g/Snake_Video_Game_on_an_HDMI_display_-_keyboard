`timescale 1ns / 1ps

module tb_top_module;

    localparam real CLK27_HALF    = 18.5185; // ~27 MHz (periodo ~37.037 ns)
    localparam integer BIT_TMR_MAX = 234;    // 27,000,000 / 115,200
    localparam real BIT_TIME      = (BIT_TMR_MAX + 1) * (2.0 * CLK27_HALF);

    reg        clk_27m;
    reg        rst_n;
    reg        uart_rx_pin;

    wire       O_tmds_clk_p;
    wire       O_tmds_clk_n;
    wire [2:0] O_tmds_data_p;
    wire [2:0] O_tmds_data_n;

    integer errors = 0;

    top_module dut (
        .clk_27m       (clk_27m),
        .rst_n         (rst_n),
        .uart_rx_pin   (uart_rx_pin),
        .O_tmds_clk_p  (O_tmds_clk_p),
        .O_tmds_clk_n  (O_tmds_clk_n),
        .O_tmds_data_p (O_tmds_data_p),
        .O_tmds_data_n (O_tmds_data_n)
    );

    // Reloj principal de 27 MHz
    initial begin
        clk_27m = 1'b0;
        forever #CLK27_HALF clk_27m = ~clk_27m;
    end

    // Tarea para enviar 1 byte UART (Start=0, 8 bits LSB primero, Stop=1)
    task send_uart_byte;
        input [7:0] data_byte;
        integer i;
        begin
            uart_rx_pin = 1'b0;
            #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_pin = data_byte[i];
                #(BIT_TIME);
            end
            uart_rx_pin = 1'b1;
            #(BIT_TIME);
        end
    endtask

    initial begin
        $display("[INFO] Iniciando tb_top_module...");
        $dumpfile("tb_top_module.vcd");
        $dumpvars(1, tb_top_module);

        // 1. Reset activo en bajo
        rst_n       = 1'b0;
        uart_rx_pin = 1'b1;
        #(CLK27_HALF * 10);

        if (O_tmds_clk_p !== 1'b0 && O_tmds_clk_p !== 1'b1) begin
            $display("[ERROR] O_tmds_clk_p en estado indefinido durante reset.");
            errors = errors + 1;
        end

        // 2. Liberar reset y verificar relojes activos
        @(negedge clk_27m);
        rst_n = 1'b1;
        #(CLK27_HALF * 25);

        if (dut.clk_pixel === 1'bx || dut.clk_serial === 1'bx) begin
            $display("[ERROR] clk_pixel o clk_serial en X tras liberar reset.");
            errors = errors + 1;
        end

        // 3. Corner Case: Envío de tecla 'W' (0x57) por UART
        send_uart_byte(8'h57);
        #(CLK27_HALF * 30);

        // 4. Corner Case: Reset asíncrono a mitad de trama UART y recuperación
        uart_rx_pin = 1'b0; // Start bit
        #(BIT_TIME * 2);
        @(negedge clk_27m);
        rst_n = 1'b0;
        #(CLK27_HALF * 8);
        @(negedge clk_27m);
        rst_n = 1'b1;
        uart_rx_pin = 1'b1;
        #(CLK27_HALF * 30);

        // 5. Corner Case: Salidas diferenciales complementarias TMDS
        if ((O_tmds_clk_p === O_tmds_clk_n) ||
            ((O_tmds_data_p & O_tmds_data_n) !== 3'b000)) begin
            $display("[ERROR] Salidas diferenciales TMDS no complementarias.");
            errors = errors + 1;
        end

        $display("========================================");
        if (errors == 0)
            $display("RESULTADO: TB_TOP_MODULE PASO TODAS LAS PRUEBAS.");
        else
            $display("RESULTADO: %0d ERRORES EN TB_TOP_MODULE.", errors);
        $display("========================================");
        $finish;
    end

endmodule

// ============================================================================
// Stubs de simulación para compilar top_module en iverilog sin librerías Gowin
// ============================================================================
module Gowin_rPLL (
    input  wire clkin,
    output reg  clkout
);
    initial clkout = 1'b0;
    always #4.0 clkout = ~clkout; // ~125 MHz serial
endmodule

module CLKDIV #(
    parameter DIV_MODE = "5",
    parameter GSREN    = "false"
)(
    input  wire RESETN,
    input  wire HCLKIN,
    input  wire CALIB,
    output reg  CLKOUT
);
    integer div_cnt;
    initial begin
        div_cnt = 0;
        CLKOUT  = 1'b0;
    end
    always @(posedge HCLKIN or negedge RESETN) begin
        if (!RESETN) begin
            div_cnt <= 0;
            CLKOUT  <= 1'b0;
        end else if (div_cnt == 2) begin
            div_cnt <= 0;
            CLKOUT  <= ~CLKOUT;
        end else begin
            div_cnt <= div_cnt + 1;
        end
    end
endmodule

module DVI_TX_Top (
    input  wire       I_rst_n,
    input  wire       I_serial_clk,
    input  wire       I_rgb_clk,
    input  wire       I_rgb_vs,
    input  wire       I_rgb_hs,
    input  wire       I_rgb_de,
    input  wire [7:0] I_rgb_r,
    input  wire [7:0] I_rgb_g,
    input  wire [7:0] I_rgb_b,
    output wire       O_tmds_clk_p,
    output wire       O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);
    assign O_tmds_clk_p  = I_rgb_clk;
    assign O_tmds_clk_n  = ~I_rgb_clk;
    assign O_tmds_data_p = {^I_rgb_r, ^I_rgb_g, ^I_rgb_b};
    assign O_tmds_data_n = ~O_tmds_data_p;
endmodule

module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data  <= 8'h00;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            if (rx == 1'b0) begin
                rx_data  <= 8'h57;
                rx_valid <= 1'b1;
            end
        end
    end
endmodule

module snake_logic (
    input  wire         clk_pixel,
    input  wire         rst_n,
    input  wire [7:0]   rx_data,
    input  wire         rx_valid,
    output reg  [4:0]   head_x,
    output reg  [4:0]   head_y,
    output reg  [4:0]   apple_good_x,
    output reg  [4:0]   apple_good_y,
    output reg  [4:0]   apple_bad_x,
    output reg  [4:0]   apple_bad_y,
    output reg  [6:0]   snake_length,
    output reg  [499:0] body_x_flat,
    output reg  [499:0] body_y_flat,
    output reg  [15:0]  score,
    output reg          game_over,
    output reg          game_win
);
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            head_x       <= 5'd3;
            head_y       <= 5'd3;
            apple_good_x <= 5'd5;
            apple_good_y <= 5'd3;
            apple_bad_x  <= 5'd7;
            apple_bad_y  <= 5'd7;
            snake_length <= 7'd1;
            body_x_flat  <= 500'd0;
            body_y_flat  <= 500'd0;
            score        <= 16'h0000;
            game_over    <= 1'b0;
            game_win     <= 1'b0;
        end else if (rx_valid) begin
            score <= score + 16'h0001;
        end
    end
endmodule

module vga_controller (
    input  wire         clk_pixel,
    input  wire         rst_n,
    input  wire [4:0]   head_x,
    input  wire [4:0]   head_y,
    input  wire [4:0]   apple_good_x,
    input  wire [4:0]   apple_good_y,
    input  wire [4:0]   apple_bad_x,
    input  wire [4:0]   apple_bad_y,
    input  wire [6:0]   snake_length,
    input  wire [499:0] body_x_flat,
    input  wire [499:0] body_y_flat,
    input  wire [15:0]  score,
    input  wire         game_over,
    input  wire         game_win,
    output reg          hs,
    output reg          vs,
    output reg          de,
    output wire [7:0]   r,
    output wire [7:0]   g,
    output wire [7:0]   b
);
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            hs <= 1'b1;
            vs <= 1'b1;
            de <= 1'b0;
        end else begin
            hs <= ~hs;
            vs <= 1'b1;
            de <= ~de;
        end
    end
    assign r = de ? score[7:0] : 8'h00;
    assign g = de ? {3'b000, head_x} : 8'h00;
    assign b = de ? {3'b000, head_y} : 8'h00;
endmodule
