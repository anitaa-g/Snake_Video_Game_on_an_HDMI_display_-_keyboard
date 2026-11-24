module uart_rx (
    input clk,          // Usaremos clk_27m
    input rst_n,
    input rx,           // Pin conectado al USB
    output reg [7:0] rx_data,
    output reg rx_valid
);
    // Para 27 MHz y 115200 baudios: 27,000,000 / 115200 = 234
    localparam BIT_TMR_MAX = 234;
    reg [7:0] bit_cnt = 0;
    reg [3:0] state = 0;
    reg [7:0] shift_reg = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0; rx_valid <= 0;
        end else begin
            rx_valid <= 0;
            case (state)
                0: if (rx == 0) begin state <= 1; bit_cnt <= BIT_TMR_MAX/2; end // Espera Start Bit
                1: if (bit_cnt == 0) begin state <= 2; bit_cnt <= BIT_TMR_MAX; end else bit_cnt <= bit_cnt - 1;
                2,3,4,5,6,7,8,9: // Lectura de 8 bits de datos
                    if (bit_cnt == 0) begin
                        shift_reg <= {rx, shift_reg[7:1]};
                        state <= state + 1;
                        bit_cnt <= BIT_TMR_MAX;
                    end else bit_cnt <= bit_cnt - 1;
                10: // Stop Bit
                    if (bit_cnt == 0) begin
                        rx_data <= shift_reg;
                        rx_valid <= 1;
                        state <= 0;
                    end else bit_cnt <= bit_cnt - 1;
            endcase
        end
    end
endmodule
