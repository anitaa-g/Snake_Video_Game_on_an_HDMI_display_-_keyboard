module snake_logic (
    input wire clk_pixel,
    input wire rst_n,
    input wire [7:0] rx_data,     
    input wire rx_valid,          

    output reg [4:0] head_x,
    output reg [4:0] head_y,

    output reg [4:0] apple_good_x, output reg [4:0] apple_good_y,
    output reg [4:0] apple_bad_x,  output reg [4:0] apple_bad_y,

    output reg [6:0] snake_length, 

    output wire [499:0] body_x_flat, 
    output wire [499:0] body_y_flat, 

    output reg [15:0] score, // AHORA DE 16 BITS (Miles, Centenas, Decenas, Unidades)

    output reg game_over,
    output reg game_win
);
    parameter MAX_LENGTH = 100; 

    reg [4:0] body_x [0:MAX_LENGTH-1];
    reg [4:0] body_y [0:MAX_LENGTH-1];

    genvar j;
    generate
        for (j = 0; j < MAX_LENGTH; j = j + 1) begin : flatten_loop
            assign body_x_flat[j*5 +: 5] = body_x[j];
            assign body_y_flat[j*5 +: 5] = body_y[j];
        end
    endgenerate
    
    reg [22:0] tick_cnt = 0; 
    wire move_tick = (tick_cnt == 23'd6_250_000); 

    always @(posedge clk_pixel or negedge rst_n) begin 
        if (!rst_n) tick_cnt <= 0; 
        else if (move_tick) tick_cnt <= 0; 
        else tick_cnt <= tick_cnt + 1;
    end
    
    reg [4:0] rand_x = 0; reg [4:0] rand_y = 0;
    always @(posedge clk_pixel) begin
        if (rand_x == 9) begin
            rand_x <= 0; rand_y <= (rand_y == 9) ? 0 : rand_y + 1;
        end else rand_x <= rand_x + 1;
    end

    localparam UP = 2'b00, DOWN = 2'b01, LEFT = 2'b10, RIGHT = 2'b11;
    reg [1:0] dir_state;
    reg [1:0] actual_dir; 

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            dir_state <= RIGHT;
        end else if (rx_valid) begin
            if (rx_data == 8'h77 && actual_dir != DOWN)       dir_state <= UP; 
            else if (rx_data == 8'h73 && actual_dir != UP)    dir_state <= DOWN; 
            else if (rx_data == 8'h61 && actual_dir != RIGHT) dir_state <= LEFT; 
            else if (rx_data == 8'h64 && actual_dir != LEFT)  dir_state <= RIGHT;
        end
    end

    wire eat_good = (head_x == apple_good_x && head_y == apple_good_y);
    wire eat_bad  = (head_x == apple_bad_x && head_y == apple_bad_y);

    reg self_collision;
    integer c;
    always @(*) begin
        self_collision = 1'b0;
        for (c = 1; c < MAX_LENGTH; c = c + 1) begin
            if (c < snake_length && head_x == body_x[c] && head_y == body_y[c]) begin
                self_collision = 1'b1;
            end
        end
    end

    integer i; 
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            head_x <= 5; head_y <= 2;
            snake_length <= 3; 
            score <= 16'h0000; // Reinicia en 0000
            
            apple_good_x <= 7; apple_good_y <= 7;
            apple_bad_x <= 3;  apple_bad_y <= 8;
            
            game_over <= 0; game_win <= 0;
            actual_dir <= RIGHT; 
            
            for (i = 0; i < MAX_LENGTH; i = i + 1) begin
                body_x[i] <= 0; body_y[i] <= 0;
            end
        end 
        else if (move_tick) begin
            if (!game_over && !game_win) begin
                
                if (self_collision) begin
                    game_over <= 1; 
                end 
                else if (snake_length >= MAX_LENGTH) begin
                    game_win <= 1;  
                end 
                else begin
                    actual_dir <= dir_state; 

                    for (i = MAX_LENGTH-1; i > 0; i = i - 1) begin
                        body_x[i] <= body_x[i-1];
                        body_y[i] <= body_y[i-1];
                    end
                    body_x[0] <= head_x;  
                    body_y[0] <= head_y; 

                    if (eat_good) begin
                        apple_good_x <= rand_x; apple_good_y <= rand_y;
                        
                        // LÓGICA BCD: Sumar 10 (Sube decenas y acarrea a centenas y miles)
                        if (score[7:4] == 4'd9) begin
                            score[7:4] <= 4'd0;
                            if (score[11:8] == 4'd9) begin
                                score[11:8] <= 4'd0;
                                if (score[15:12] < 4'd9) score[15:12] <= score[15:12] + 1'b1; // Sube miles
                            end else begin
                                score[11:8] <= score[11:8] + 1'b1;
                            end
                        end else begin
                            score[7:4] <= score[7:4] + 1'b1;
                        end

                        if (snake_length < MAX_LENGTH) snake_length <= snake_length + 1;
                    end
                    
                    if (eat_bad) begin
                        apple_bad_x <= (9 - rand_x); 
                        apple_bad_y <= (9 - rand_y);
                        
                        // LÓGICA BCD: Restar 5 pidiendo prestado hasta los miles
                        if (score != 16'h0000) begin
                            if (score[3:0] == 4'd5) begin
                                score[3:0] <= 4'd0; 
                            end 
                            else begin
                                score[3:0] <= 4'd5;
                                if (score[7:4] == 4'd0) begin
                                    score[7:4] <= 4'd9;
                                    if (score[11:8] == 4'd0) begin
                                        score[11:8] <= 4'd9;
                                        if (score[15:12] > 4'd0) score[15:12] <= score[15:12] - 1'b1; // Pide a miles
                                    end else begin
                                        score[11:8] <= score[11:8] - 1'b1; // Pide a centenas
                                    end
                                end else begin
                                    score[7:4] <= score[7:4] - 1'b1; // Pide a decenas
                                end
                            end
                        end
                        
                        if (snake_length > 0) begin
                            snake_length <= snake_length - 1; 
                        end else begin
                            game_over <= 1; 
                        end
                    end

                    case (dir_state)
                        UP:    head_y <= (head_y == 0) ? 9 : head_y - 1;
                        DOWN:  head_y <= (head_y == 9) ? 0 : head_y + 1;
                        LEFT:  head_x <= (head_x == 0) ? 9 : head_x - 1;
                        RIGHT: head_x <= (head_x == 9) ? 0 : head_x + 1;
                    endcase
                end
            end
        end
    end
endmodule
