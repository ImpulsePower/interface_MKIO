module device3 
# ( parameter [4:0] ADDRESS = 5'd1 ) 
(
    input clk,
    input reset, 
    input start,
    // RX INTERFACE
    input        rx_done,
    input [15:0] rx_data,
    input        p_error,
    // TX INTERFACE
    output reg [15:0] tx_data,
    output reg        tx_cd,
    output reg        tx_ready,
    input             tx_busy,
    // MEMORY INTERFACE
    input  [4:0]  addr_rd,
    input         clk_rd,
    output [15:0] out_data,
    output reg    busy
);

// Подмодуль памяти
mem_dev3 mem_dev3_sb (
    .data      (in_data),
    .wraddress (addr_wr),
    .wren      (we),
    .rdaddress (addr_rd),
    .wrclock   (clk_wr), 
    .rdclock   (clk_rd), 
    .q         (out_data)
);

// Расчёт количество слов которые необходимо принять (N/COM МКИО ГОСТ)
reg [4:0] num_word = 5'd0;
reg [4:0] num_word_buf = 5'd0;

always @ (num_word)
    case (num_word)
        5'd0:    num_word_buf = 5'd31;
        default: num_word_buf = num_word - 1'b1;
    endcase

reg [4:0]   addr_wr;
reg         clk_wr;
reg         we;
// Приём данных из памяти
wire [15:0] in_data = rx_data;

// Список состояний конечного автомата
parameter IDLE_STATE      = 8'd0,
          START_STATE     = 8'd1,
          DATA_WAIT_STATE = 8'd2,
          DATA_SAVE_STATE = 8'd3,
          CHECK_NUM_STATE = 8'd4,
          LOAD_OS_STATE   = 8'd5,
          SEND_OS_STATE   = 8'd6,
          END_WAIT_STATE  = 8'd7;

reg [4:0] cnt_word;
reg [5:0] cnt_p;
reg [7:0] STATE;

reg [7:0] cnt_pause;
reg [1:0] delay_impulse = 2'h2; //2 clk

always @ (posedge clk or posedge start or posedge reset) begin : state_machine

    if (reset) begin
        STATE <= IDLE_STATE;
        tx_data  <= 16'd0;
        addr_wr  <= 5'd0;
        we       <= 1'b0;
        clk_wr   <= 1'b0;
        cnt_word <= 5'd0;
        cnt_p    <= 6'd0;
        tx_ready <= 1'b0;
        busy     <= 1'b0; 
    end

    else if (start) begin
        STATE <= START_STATE;
        addr_wr  <= 5'd0;
        we       <= 1'b1;
        clk_wr   <= 1'b0;
        cnt_word <= 5'd0;
        cnt_p    <= 6'd0;
        tx_ready <= 1'b0;
        busy     <= 1'b1; 
    end

    else case (STATE)
    // Состояние ожидания импульса на старт приема информационных слов
        IDLE_STATE:begin
            STATE <= IDLE_STATE;
            addr_wr  <= 5'd0;
            tx_ready <= 1'b0;
            tx_data  <= 16'd0;
            tx_cd    <= 1'b0;
            we       <= 1'b0;
            busy     <= 1'b0;
            cnt_pause <= 8'h0;
        end

    // Начало обработки информационного слова
        START_STATE:begin
            STATE    <= DATA_WAIT_STATE;
            num_word <= rx_data[4:0];
            if (p_error) cnt_p <= cnt_p + 1'b1;
        end
        
    // Состояние ожидания следующего информационного слова
        DATA_WAIT_STATE:begin
            if (rx_done) STATE <= DATA_SAVE_STATE;
            else         STATE <= DATA_WAIT_STATE;
        end

    // Состояние сохранения информационного слова
        DATA_SAVE_STATE:begin
            STATE  <= CHECK_NUM_STATE;
            clk_wr <= 1'b1;
            if (p_error) cnt_p <= cnt_p + 1'b1;
        end

    // Состояние проверки количества принятых информационных слов
        CHECK_NUM_STATE:begin
            clk_wr <= 1'b0;
            if (cnt_word == num_word_buf) begin
                cnt_word <= 5'd0;
                STATE <= LOAD_OS_STATE; 
            end
            else begin
                addr_wr <= addr_wr + 1'b1;
                cnt_word <= cnt_word + 1'b1;
                STATE <= DATA_WAIT_STATE; 
            end
        end

    // Состояние подготовки ответного слова
        LOAD_OS_STATE:begin
            STATE   <= SEND_OS_STATE;
            tx_cd   <= 1'b0;
        end

    // Состояние отправки ответного слова на контроллер канала
        SEND_OS_STATE:begin
            tx_ready <= 1'b1;
            tx_data <= {ADDRESS, | cnt_p, 10'd0};
            if (clk) begin
                cnt_pause <= cnt_pause + 1'h1;
                if (cnt_pause == delay_impulse) begin
                    STATE <= END_WAIT_STATE;
                    cnt_pause <= 2'h0;
                    tx_ready  <= 1'b0;
                end      
            end
        end

        END_WAIT_STATE:begin 
            if (tx_busy) STATE <= END_WAIT_STATE;
            else         STATE <= IDLE_STATE;
        end

    endcase
end

endmodule