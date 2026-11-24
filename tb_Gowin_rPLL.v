`timescale 1ns / 1ps

module tb_Gowin_rPLL;

    localparam real CLK27_HALF = 18.5185; // ~27 MHz (periodo ~37.037 ns)

    reg  clkin;
    reg  stop_clkin;
    wire clkout;

    integer errors = 0;
    real    t_edge1, t_edge2, period_out;

    Gowin_rPLL dut (
        .clkout (clkout),
        .clkin  (clkin)
    );

    // Reloj de entrada de 27 MHz con control de pausa para probar corner cases
    initial begin
        clkin = 1'b0;
        stop_clkin = 1'b0;
        forever begin
            if (!stop_clkin) begin
                #CLK27_HALF clkin = ~clkin;
            end else begin
                #CLK27_HALF;
            end
        end
    end

    initial begin
        $display("[INFO] Iniciando tb_Gowin_rPLL...");
        $dumpfile("tb_Gowin_rPLL.vcd");
        $dumpvars(1, tb_Gowin_rPLL);

        // 1. Verificar salida valida tras varios ciclos de clkin (27 MHz)
        #(CLK27_HALF * 12);
        #1;
        if (clkout !== 1'b0 && clkout !== 1'b1) begin
            $display("[ERROR] clkout en estado indefinido tras inicio.");
            errors = errors + 1;
        end

        // 2. Medir periodo real de clkout entre dos flancos de subida
        @(posedge clkout);
        t_edge1 = $realtime;
        @(posedge clkout);
        t_edge2 = $realtime;
        period_out = t_edge2 - t_edge1;
        $display("[INFO] Periodo medido en clkout: %0.3f ns", period_out);

        if (period_out <= 0.0) begin
            $display("[ERROR] Periodo de clkout invalido (%0.3f ns).", period_out);
            errors = errors + 1;
        end

        // 3. Corner Case: Pausa momentanea en clkin y reanudacion del reloj
        stop_clkin = 1'b1;
        #(CLK27_HALF * 8);
        stop_clkin = 1'b0;
        #(CLK27_HALF * 16);
        #1;

        if (clkout !== 1'b0 && clkout !== 1'b1) begin
            $display("[ERROR] clkout quedo en estado invalido tras reanudar clkin.");
            errors = errors + 1;
        end

        // 4. Operacion continua prolongada
        #(CLK27_HALF * 30);

        $display("========================================");
        if (errors == 0)
            $display("RESULTADO: TB_GOWIN_RPLL PASO TODAS LAS PRUEBAS.");
        else
            $display("RESULTADO: %0d ERRORES EN TB_GOWIN_RPLL.", errors);
        $display("========================================");
        $finish;
    end

endmodule

// ============================================================================
// Stub de simulación de la primitiva rPLL de Gowin para iverilog / EDA Playground
// ============================================================================
module rPLL #(
    parameter        FCLKIN           = "27",
    parameter        DYN_IDIV_SEL     = "false",
    parameter        IDIV_SEL         = 0,
    parameter        DYN_FBDIV_SEL    = "false",
    parameter        FBDIV_SEL        = 1,
    parameter        DYN_ODIV_SEL     = "false",
    parameter        ODIV_SEL         = 1,
    parameter        PSDA_SEL         = "0000",
    parameter        DYN_DA_EN        = "false",
    parameter        DUTYDA_SEL       = "1000",
    parameter        CLKOUT_FT_DIR    = 1'b1,
    parameter        CLKOUTP_FT_DIR   = 1'b1,
    parameter        CLKOUT_DLY_STEP  = 0,
    parameter        CLKOUTP_DLY_STEP = 0,
    parameter        CLKFB_SEL        = "internal",
    parameter        CLKOUT_BYPASS    = "false",
    parameter        CLKOUTP_BYPASS   = "false",
    parameter        CLKOUTD_BYPASS   = "false",
    parameter        DYN_SDIV_SEL     = 2,
    parameter        CLKOUTD_SRC      = "CLKOUT",
    parameter        CLKOUTD3_SRC     = "CLKOUT",
    parameter        DEVICE           = "GW1NR-9C"
)(
    output reg         CLKOUT,
    output reg         LOCK,
    output reg         CLKOUTP,
    output reg         CLKOUTD,
    output reg         CLKOUTD3,
    input  wire        RESET,
    input  wire        RESET_P,
    input  wire        CLKIN,
    input  wire        CLKFB,
    input  wire [5:0]  FBDSEL,
    input  wire [5:0]  IDSEL,
    input  wire [5:0]  ODSEL,
    input  wire [3:0]  PSDA,
    input  wire [3:0]  DUTYDA,
    input  wire [3:0]  FDLY
);
    integer div_cnt;
    initial begin
        CLKOUT   = 1'b0;
        LOCK     = 1'b1;
        CLKOUTP  = 1'b0;
        CLKOUTD  = 1'b0;
        CLKOUTD3 = 1'b0;
        div_cnt  = 0;
    end

    always @(posedge CLKIN) begin
        if (RESET || RESET_P) begin
            CLKOUT  <= 1'b0;
            LOCK    <= 1'b0;
            div_cnt <= 0;
        end else begin
            LOCK   <= 1'b1;
            CLKOUT <= ~CLKOUT;
            if (div_cnt == 2) begin
                div_cnt <= 0;
                CLKOUTD <= ~CLKOUTD;
            end else begin
                div_cnt <= div_cnt + 1;
            end
        end
    end
endmodule