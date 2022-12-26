// rx_data - шина принятого слова
// p_error - флаг несоответствия паритета в принятом слове
// tx_data - шина передачи ответного слова на контроллер канала
// tx_cd - флаг-указатель на тип передаваемого слова, 0: ответное слово, 1: информационное слово
// tx_ready - импульс для начала передачи
// addr_wr - адрес для записи в память
// clk_wr - тактовый сигнал для памяти
// in_data - Приём данных из памяти
// we - флаг разрешение записи
// busy - флаг статуса линии
// cnt_p - счётчик, ошибок паритета в принимаемом пакете
// cnt - вспомогательный счётчик

module device5 
# ( parameter [4:0] ADDRESS = 5'd1) 
(
    input clk,
    input reset,
    input start,
    // RX INTERFACE
    input [15:0] rx_data,
    input        p_error,
    // TX INTERFACE
    output reg [15:0] tx_data,
    output reg        tx_cd,
    output reg        tx_ready,
    // MEMORY INTERFACE
    input [4:0]  addr_wr,
    input        clk_wr,
    input [15:0] in_data,
    input        we,
    output reg   busy
);

// reg [4:0] addr_wr;
// reg clk_wr;
// reg we;
// wire [15:0] in_data = rx_data;

parameter IDLE_STATE       = 8'd0,
          START_STATE      = 8'd1,
          PAUSE_WAIT_STATE = 8'd2,
          LOAD_OS_STATE    = 8'd3,
          SEND_OS_STATE    = 8'd4,
          READ_DATA_STATE  = 8'd5,
          PREP_DATA_STATE  = 8'd6,
          SEND_WAIT_STATE  = 8'd7,
          SEND_DATA_STATE  = 8'd8,
          CHECK_NUM_STATE  = 8'd9,
          END_WAIT_STATE   = 8'd10;

reg [4:0] cnt_word;
reg [5:0] cnt_p;
reg [7:0] cnt;
reg [7:0] STATE;

// Расчёт количество слов которые необходимо принять (N/COM МКИО ГОСТ)
reg [4:0] num_word = 5'd0;
reg [4:0] num_word_buf = 5'd0;

always @ (num_word)
    case (num_word)
        5'd0:    num_word_buf = 5'd31;
        default: num_word_buf = num_word - 1'b1;
    endcase
    
always @ (posedge clk or posedge start or posedge reset) begin : state_machine

    if (reset) begin
        STATE <= IDLE_STATE;
        tx_data  <= 16'd0;
        cnt      <= 8'd0;
        cnt_p    <= 6'd0;
        tx_ready <= 1'b0;
        busy     <= 1'b0;
    end

    else if (start)begin
        STATE <= START_STATE;
        cnt_p    <= 6'd0;
        cnt      <= 8'd0;
        busy     <= 1'b1; 
    end

    else case (STATE)
    // Состояние ожидания импульса на старт приема информационных слов
        IDLE_STATE:begin
            STATE <= IDLE_STATE;
            tx_ready <= 1'b0;
            busy     <= 1'b0;
        end

    // Сохранение количества информационных слов
        START_STATE:begin
            STATE <= PAUSE_WAIT_STATE;
            num_word <= rx_data[4:0];
            if (p_error) cnt_p <= cnt_p + 1'b1;
        end

    // Отсчитывание кол.тактов, которое соответствует паузе между КС и ОС
        PAUSE_WAIT_STATE:begin
            STATE <= LOAD_OS_STATE;
        end

    // Подготовка ответного слова (адрес устройства, биты статуса)
        LOAD_OS_STATE:begin
            STATE <= READ_DATA_STATE;
            tx_cd   <= 1'b0;
            tx_data <= {ADDRESS, | cnt_p, 10'd0};
        end

    // Отправка ответного слова на контроллер канала (tx_ready = '1')
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

    // Чтение данных из внутренней ОЗУ
        READ_DATA_STATE:begin
            STATE <= PREP_DATA_STATE;
        end

    // Подготовка инф.слова для передачи на контроллер канала
        PREP_DATA_STATE:begin
            STATE <= SEND_WAIT_STATE;
        end

    // Ожидание окончания отправки предыдущего слова на контроллер канала
        SEND_WAIT_STATE:begin
            if (busy) STATE <= SEND_DATA_STATE;
            else      STATE <= CHECK_NUM_STATE;
        end

    // Передача инф.слова на контроллер канала
        SEND_DATA_STATE:begin
            STATE <= PAUSE_WAIT_STATE;
        end

    // Проверка количества отправленных информационных слов
        CHECK_NUM_STATE:begin
            // clk_wr <= 1'b0;
            // addr_wr <= addr_wr + 1'b1;
            if (cnt_word == num_word_buf) begin
                cnt_word <= 5'd0;
                STATE <= END_WAIT_STATE; 
            end
            else begin
                cnt_word <= cnt_word + 1'b1;
                STATE <= PAUSE_WAIT_STATE; 
            end
        end

    // Окончание передачи всей информации на контроллер канала
        END_WAIT_STATE:begin
            STATE <= IDLE_STATE;
            cnt <= 8'd0;
        end            
    endcase
end

// Подмодуль памяти
mem_dev5 mem_dev5 (
    .data      (in_data),
    .wraddress (addr_wr),
    .wren      (we),
    .rdaddress (addr_rd),
    .wrclock   (clk_wr), 
    .rdclock   (clk_rd), 
    .q         (out_data)
);

endmodule