module device5 
# ( parameter [4:0] ADDRESS = 5'd1 ) 
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
    input             tx_busy,
    // MEMORY INTERFACE
    input [4:0]  addr_wr,
    input        clk_wr,
    input [15:0] in_data,
    input        we,
    output reg   busy
);

// Подмодуль памяти
mem_dev5 mem_dev5_sb (
    .data      (in_data),
    .wraddress (addr_wr),
    .wren      (we),
    .rdaddress (addr_rd),
    .wrclock   (clk_wr), 
    .rdclock   (clk_rd), 
    .q         (out_data)
);

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
reg [7:0] STATE;

reg  [4:0]  addr_rd;
wire [15:0] out_data;
reg  [15:0] rd_data;
reg         clk_rd;

reg [7:0] cnt_pause;
// Delays
reg [7:0] delay_CW_RW = 8'hFF; //8 us
reg [1:0] delay_impulse = 2'h2; //2 clk
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
        cnt_p    <= 6'd0;
        tx_data   <= 16'd0;
        clk_rd   <= 1'b0;
        cnt_word <= 5'd0;
        addr_rd  <= 1'b0;
    end

    else if (start)begin
        STATE <= START_STATE;
        tx_data  <= 16'd0;
        cnt_p    <= 6'd0;
        busy     <= 1'b0;
        addr_rd  <= 1'b0;
        clk_rd   <= 1'b0;
        cnt_word <= 5'd0;
    end

    else case (STATE)
    // Состояние ожидания импульса на старт приема информационных слов
        IDLE_STATE:begin
            STATE     <= IDLE_STATE;
            tx_ready  <= 1'b0;
            tx_data   <= 16'd0;
            busy      <= 1'b0;
            cnt_pause <= 8'h0;
            addr_rd  <= 1'b0;
        end

    // Сохранение количества информационных слов
        START_STATE:begin
            num_word <= rx_data[4:0];
            if (p_error) cnt_p <= cnt_p + 1'b1;
            STATE <= PAUSE_WAIT_STATE;
        end

    // Отсчитывание кол.тактов, которое соответствует паузе между КС и ОС
        PAUSE_WAIT_STATE:begin
            if (clk) begin
                cnt_pause <= cnt_pause + 1'h1;
                if (cnt_pause == delay_CW_RW) STATE <= LOAD_OS_STATE;
            end
        end

    // Подготовка ответного слова (адрес устройства, биты статуса)
        LOAD_OS_STATE:begin
            STATE <= SEND_OS_STATE;
            tx_cd   <= 1'b0;
            tx_data <= {ADDRESS, | cnt_p, 10'd0};
        end

    // Отправка ответного слова на контроллер канала (tx_ready = '1')
        SEND_OS_STATE:begin
            tx_ready <= 1'b1;
            if (clk) begin
                cnt_pause <= cnt_pause + 1'h1;
                if (cnt_pause == delay_impulse) begin
                    cnt_pause <= 8'h0;
                    tx_ready <= 1'b0;
                    STATE <= READ_DATA_STATE;
                end      
            end
        end

    // Чтение данных из внутренней ОЗУ
        READ_DATA_STATE:begin
            clk_rd <= 1'b1;
            STATE  <= PREP_DATA_STATE;
        end

    // Подготовка инф.слова для передачи на контроллер канала
        PREP_DATA_STATE:begin
            clk_rd  <= 1'b0;
            tx_cd   <= 1'b1;
            busy    <= 1'b1;
            STATE   <= SEND_WAIT_STATE;
        end

    // Ожидание окончания отправки предыдущего слова на контроллер канала
        SEND_WAIT_STATE:begin
            if (tx_busy) STATE <= SEND_WAIT_STATE;
            else         STATE <= SEND_DATA_STATE;    
        end

        SEND_DATA_STATE:begin
            tx_ready <= 1'b1;
            tx_data  <= out_data;
            if (clk) begin
                cnt_pause <= cnt_pause + 1'h1;
                if (cnt_pause == delay_impulse) begin
                    cnt_pause <= 8'h0;
                    tx_ready  <= 1'b0;
                    STATE <= CHECK_NUM_STATE;
                end      
            end
        end

    // Проверка количества отправленных информационных слов
        CHECK_NUM_STATE:begin
            clk_rd  <= 1'b0;
            if (cnt_word == num_word_buf) begin
                cnt_word <= 5'd0;
                addr_rd  <= 1'b0;
                STATE    <= END_WAIT_STATE; 
            end
            else begin
                addr_rd  <= addr_rd + 1'b1;
                cnt_word <= cnt_word + 1'b1;
                STATE    <= READ_DATA_STATE; 
            end
        end

    // Окончание передачи всей информации на контроллер канала
        END_WAIT_STATE:begin 
            if (tx_busy) STATE <= END_WAIT_STATE;
            else         STATE <= IDLE_STATE;
        end
                          
    endcase
end

endmodule