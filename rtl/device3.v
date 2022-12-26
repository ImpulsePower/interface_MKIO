// Импульс start инициирует процесс приема данных и запись в память ПЛИС
// rx_done - флаг прихода информационного слова
// rx_data - шина принятого слова
// p_error - флаг несоответствия паритета в принятом слове
// tx_data - шина передачи ответного слова на контроллер канала
// tx_cd - флаг-указатель на тип передаваемого слова, 0: ответное слово, 1: информационное слово
// tx_ready - импульс для начала передачи
// addr_rd - адрес данных для памяти
// clk_rd  - тактовый сигнал для памяти
// out_data - данные для передачи в память
// busy - флаг статуса линии
// addr_wr - адрес для записи в память
// clk_wr - тактовый сигнал для памяти
// we - флаг разрешение записи
// cnt_word - счётчик, поступивших информационных слов
// cnt_p - счётчик, ошибок паритета в принимаемом пакете
// cnt - вспомогательный счётчик

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
    // MEMORY INTERFACE
    input  [4:0]  addr_rd,
    input         clk_rd,
    output [15:0] out_data,
    output reg    busy
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
          SEND_OS_STATE   = 8'd6;

reg [4:0] cnt_word;
reg [5:0] cnt_p;
reg [7:0] cnt, STATE;

always @ (posedge clk or posedge start or posedge reset) begin : state_machine

    if (reset) begin
        STATE <= IDLE_STATE;
        tx_data  <= 16'd0;
        addr_wr  <= 5'd0;
        we       <= 1'b0;
        clk_wr   <= 1'b0;
        cnt_word <= 5'd0;
        cnt_p    <= 6'd0;
        cnt      <= 8'd0;
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
        cnt      <= 16'd0;
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
            addr_wr <= addr_wr + 1'b1;
            if (cnt_word == num_word_buf) begin
                cnt_word <= 5'd0;
                STATE <= LOAD_OS_STATE; 
            end
            else begin
                cnt_word <= cnt_word + 1'b1;
                STATE <= DATA_WAIT_STATE; 
            end
        end

    // Состояние подготовки ответного слова
        LOAD_OS_STATE:begin
            STATE   <= SEND_OS_STATE;
            tx_cd   <= 1'b0;
            tx_data <= {ADDRESS, | cnt_p, 10'd0};
        end

    // Состояние отправки ответного слова на контроллер канала
        SEND_OS_STATE:begin
            tx_ready <= 1'b1;
            if (cnt == 8'd1) begin
                STATE <= IDLE_STATE;
                cnt <= 8'd0; 
            end
            else begin
                STATE <= SEND_OS_STATE;
                cnt <= cnt + 1'b1; 
            end
        end
    endcase
end

// Подмодуль памяти
mem_dev3 mem_dev3 (
    .data      (in_data),
    .wraddress (addr_wr),
    .wren      (we),
    .rdaddress (addr_rd),
    .wrclock   (clk_wr), 
    .rdclock   (clk_rd), 
    .q         (out_data)
);

endmodule