// DI1, DI0 - дифференциальный вход
// data_get - принятые данные по триггеру done
// cd_get - указатель на тип слова
// done - импульс окончания приёма данных
// parity_error - правило паритета

module mkio_receiver (
    input clk,
    input reset,
    input DI1, DI0,
    output reg [15:0] data_get,
    output reg cd_get,
    output reg done,
    output reg parity_error
);

// Модуль синхронизации
reg [2:0] pos_shift_reg;
reg [2:0] neg_shift_reg;

always @ (posedge clk or posedge reset) begin
    if (reset) begin
        pos_shift_reg <= 3'd0;
        neg_shift_reg <= 3'd0; end
    else begin
        pos_shift_reg <= {pos_shift_reg[1:0], DI1};
        neg_shift_reg <= {neg_shift_reg[1:0], DI0}; 
    end
end

// Детектирование начала приёма
reg det_sig;

always @ (posedge clk or posedge reset) begin
    if (reset) det_sig <= 1'b0;
    else case ({pos_shift_reg[2], neg_shift_reg[2]})
        2'b00: det_sig <= ~det_sig;
        2'b01: det_sig <= 1'b0;
        2'b10: det_sig <= 1'b1;
        2'b11: det_sig <= ~det_sig;
    endcase
end

// Фиксация момента начало приёма элемента манч.кода
reg [2:0] sig_shift_reg;
wire in_data;
wire reset_length_bit;

always @ (posedge clk or posedge reset) begin
    if (reset) sig_shift_reg <= 3'd0;
    else sig_shift_reg[2:0] <= {sig_shift_reg[1:0], det_sig};
end
assign in_data = sig_shift_reg[2];
assign reset_length_bit = sig_shift_reg[2] ^ sig_shift_reg[1];

// Сборка манч.кода в сдвиговый регистр manchester_reg
reg [2:0] length_bit;
wire middle_bit;
reg [39:0] manchester_reg;
assign middle_bit = (length_bit == 3'd3);

always @ (posedge clk or posedge reset) begin
    if (reset) begin
        length_bit <= 3'd0;
        manchester_reg <= 40'd0; end
    else begin
    if (reset_length_bit) length_bit <= 3'd0;
    else length_bit <= length_bit + 1'b1;
    if (middle_bit)
        manchester_reg[39:0] <= {manchester_reg[38:0], in_data};
    end
end

// Выделяет из регистра сигнал паритета, тип синхронизации и поле данных
wire true_data_packet;
wire [15:0] data_buf;
wire parity_buf;
wire cd_buf;

assign true_data_packet =
        ((manchester_reg[39:34] == 6'b000111) |
         (manchester_reg[39:34] == 6'b111000))
        & (manchester_reg[33] ^ manchester_reg[32])
        & (manchester_reg[31] ^ manchester_reg[30]);
genvar i;
generate for (i = 0; i <= 15; i = i + 1) begin : bit_a
    assign data_buf[i] = manchester_reg[2*i+3];
end
endgenerate
assign parity_buf = manchester_reg[1];
assign cd_buf = manchester_reg[35];

// По окончанию приёма выставляеются на выход принятые данные
reg ena_wr;
always @ (posedge clk or posedge reset) begin
    if (reset) begin
        cd_get <= 1'b0;
        parity_error <= 1'b0;
        ena_wr <= 1'b0;
        data_get <= 16'd0;
    end
    else begin ena_wr <= middle_bit;
    if (true_data_packet & ena_wr) begin
        cd_get <= cd_buf;
        data_get <= data_buf[15:0];
        parity_error <= ~(^({data_buf,parity_buf}));
    end
    done <= true_data_packet & ena_wr;
    end
end
								 
endmodule