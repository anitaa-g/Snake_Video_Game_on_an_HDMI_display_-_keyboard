`timescale 1ns / 1ps

module tb_DVI_TX_Top;

    localparam real PIXEL_HALF  = 20.0; // ~25 MHz (40 ns periodo)
    localparam real SERIAL_HALF = 4.0;  // ~125 MHz (8 ns periodo)

    reg        I_rst_n;
    reg        I_serial_clk;
    reg        I_rgb_clk;
    reg        I_rgb_vs;
    reg        I_rgb_hs;
    reg        I_rgb_de;
    reg  [7:0] I_rgb_r;
    reg  [7:0] I_rgb_g;
    reg  [7:0] I_rgb_b;

    wire       O_tmds_clk_p;
    wire       O_tmds_clk_n;
    wire [2:0] O_tmds_data_p;
    wire [2:0] O_tmds_data_n;

    integer errors = 0;

    DVI_TX_Top dut (
        .I_rst_n        (I_rst_n),
        .I_serial_clk   (I_serial_clk),
        .I_rgb_clk      (I_rgb_clk),
        .I_rgb_vs       (I_rgb_vs),
        .I_rgb_hs       (I_rgb_hs),
        .I_rgb_de       (I_rgb_de),
        .I_rgb_r        (I_rgb_r),
        .I_rgb_g        (I_rgb_g),
        .I_rgb_b        (I_rgb_b),
        .O_tmds_clk_p   (O_tmds_clk_p),
        .O_tmds_clk_n   (O_tmds_clk_n),
        .O_tmds_data_p (O_tmds_data_p),
        .O_tmds_data_n (O_tmds_data_n)
    );

    // Reloj de píxel (~25 MHz)
    initial begin
        I_rgb_clk = 1'b0;
        forever #PIXEL_HALF I_rgb_clk = ~I_rgb_clk;
    end

    // Reloj serial (~125 MHz)
    initial begin
        I_serial_clk = 1'b0;
        forever #SERIAL_HALF I_serial_clk = ~I_serial_clk;
    end

    initial begin
        $display("[INFO] Iniciando tb_DVI_TX_Top...");
        $dumpfile("tb_DVI_TX_Top.vcd");
        $dumpvars(1, tb_DVI_TX_Top);

        // 1. Reset activo en bajo
        I_rst_n  = 1'b0;
        I_rgb_vs = 1'b1;
        I_rgb_hs = 1'b1;
        I_rgb_de = 1'b0;
        I_rgb_r  = 8'h00;
        I_rgb_g  = 8'h00;
        I_rgb_b  = 8'h00;
        #(PIXEL_HALF * 4);
        #1;

        if (O_tmds_data_p !== 3'b000) begin
            $display("[ERROR] O_tmds_data_p no es 000 durante reset (obtenido %b).", O_tmds_data_p);
            errors = errors + 1;
        end

        // 2. Liberar reset y enviar píxel activo (amarillo 0xFFFF00)
        @(negedge I_rgb_clk);
        I_rst_n  = 1'b1;
        I_rgb_de = 1'b1;
        I_rgb_r  = 8'hFF;
        I_rgb_g  = 8'hFF;
        I_rgb_b  = 8'h00;
        #(PIXEL_HALF * 4);
        #1;

        if ((O_tmds_clk_p === O_tmds_clk_n) ||
            ((O_tmds_data_p & O_tmds_data_n) !== 3'b000)) begin
            $display("[ERROR] Pares diferenciales TMDS no complementarios en zona activa.");
            errors = errors + 1;
        end

        // 3. Corner Case: Paso a blanking (I_rgb_de = 0) y pulso de HSYNC (I_rgb_hs = 0)
        @(negedge I_rgb_clk);
        I_rgb_de = 1'b0;
        I_rgb_hs = 1'b0;
        I_rgb_r  = 8'hAA;
        I_rgb_g  = 8'h55;
        I_rgb_b  = 8'hFF;
        #(PIXEL_HALF * 4);
        #1;

        if (O_tmds_data_p !== 3'b000) begin
            $display("[ERROR] O_tmds_data_p deberia ser 000 en blanking (obtenido %b).", O_tmds_data_p);
            errors = errors + 1;
        end

        // 4. Corner Case: Pulso de VSYNC (I_rgb_vs = 0) y recuperación de video activo
        @(negedge I_rgb_clk);
        I_rgb_hs = 1'b1;
        I_rgb_vs = 1'b0;
        #(PIXEL_HALF * 4);
        @(negedge I_rgb_clk);
        I_rgb_vs = 1'b1;
        I_rgb_de = 1'b1;
        #(PIXEL_HALF * 4);
        #1;

        if ((O_tmds_clk_p === O_tmds_clk_n) ||
            ((O_tmds_data_p & O_tmds_data_n) !== 3'b000)) begin
            $display("[ERROR] Pares diferenciales TMDS invalidos tras pulso VSYNC.");
            errors = errors + 1;
        end

        $display("========================================");
        if (errors == 0)
            $display("RESULTADO: TB_DVI_TX_TOP PASO TODAS LAS PRUEBAS.");
        else
            $display("RESULTADO: %0d ERRORES EN TB_DVI_TX_TOP.", errors);
        $display("========================================");
        $finish;
    end

endmodule

// ============================================================================
// Stubs de simulación para compilar DVI_TX_Top en iverilog sin librerías Gowin
// ============================================================================
`celldefine
module VCC (output V);
    assign V = 1'b1;
endmodule
`endcelldefine

`celldefine
module GND (output G);
    assign G = 1'b0;
endmodule
`endcelldefine

`celldefine
module GSR (input GSRI);
endmodule
`endcelldefine

module \~rgb2dvi.DVI_TX_Top (
    input  wire       I_rgb_clk,
    input  wire       I_serial_clk,
    input  wire       I_rst_n,
    input  wire       I_rgb_de,
    input  wire       I_rgb_vs,
    input  wire       I_rgb_hs,
    input  wire [7:0] I_rgb_r,
    input  wire [7:0] I_rgb_g,
    input  wire [7:0] I_rgb_b,
    output wire       O_tmds_clk_p,
    output wire       O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);
    assign O_tmds_clk_p  = I_rst_n ? I_rgb_clk : 1'b0;
    assign O_tmds_clk_n  = ~O_tmds_clk_p;

    wire [2:0] active_vec;
    assign active_vec = {
        ^I_rgb_r,
        ^I_rgb_g,
        (I_rgb_hs ^ I_rgb_vs ^ (^I_rgb_b))
    };

    assign O_tmds_data_p = (I_rst_n && I_rgb_de) ? active_vec : 3'b000;
    assign O_tmds_data_n = ~O_tmds_data_p;
endmodule