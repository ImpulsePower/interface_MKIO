// imp_send - защелка парал. данных и триггер передачи манч.кода по DO1, DO0
// imp_send - указатель на тип синхросигнала
// data_send - передаваемые данные
// data_send - флаг статуса линии ('1' - занята)
// DO1, DO0 - диференциальные линии
// data_buf - шина "защелкнутых" данных
// cd_buf - "защелкнутый" бит нужного синхросигнала
// length_bit - счётчик длины элемента word_manchester
// count_bit - номер элемента манч.кода
// data_manchester - манч.слово без синхросигнала и паритета (2xdata_send)
// word_manchester - полное манч.слово
// parity - сигнал паритета

module mkio_transmitter (
	input clk,
	input reset,
	input        imp_send,
	input        cd_send,
	input [15:0] data_send,
	output reg   busy_send,   
	output reg   DO1, DO0
);

reg  [15:0] data_buf;
reg         cd_buf;
reg  [2:0]  length_bit;
reg  [5:0]  count_bit;

wire [31:0] data_manchester;
wire [39:0] word_manchester;
wire        parity;

// Формирование манч. посылки
// Преобразование поле данных в манчестерский вид 
genvar i;
generate for (i = 0; i < 16; i = i + 1) begin : gen_manchester
        assign data_manchester[2*i]     = ~data_buf[i];
        assign data_manchester[2*i + 1] = data_buf[i];
    end
endgenerate
// Выбор синхросигнала > присвоение поле данных > 
// > присвоение пары элементов в зав. от бит паритета > вычисление бита паритета
assign word_manchester[39:34] = (cd_buf) ? 6'b000111 : 6'b111000;
assign word_manchester[33:2] = data_manchester;
assign word_manchester[1:0] = (parity) ? 2'b10 : 2'b01;
assign parity = ~(^ data_buf);

always @ (posedge clk or posedge reset)
begin
    if (reset) begin
        busy_send  <= 1'b0;
        data_buf   <= 16'd0;
        cd_buf     <= 1'b0;
        length_bit <= 3'd0;
        count_bit  <= 6'd0;
    end
    else begin
        // "Защелкивание" входных данных для передачи по приходу imp_send
        if (imp_send) begin
            data_buf <= data_send;
            cd_buf <= cd_send; 
        end
        // Подсчёт длительности элемента манч.кода
        if (imp_send) length_bit <= 3'd0;
        else if (busy_send) length_bit <= length_bit + 1'b1;
        // декремент номера элемента последовательности манч.кода count_bit
        if (imp_send) count_bit <= 6'd39;
        else if ((count_bit != 6'd0) & (length_bit == 3'd7))
        count_bit <= count_bit - 1'b1;
        // Процесс передачи манч.кода и изменением статуса линии 
        if (imp_send) busy_send <= 1'b1;
        else if ((count_bit == 6'd0) & (length_bit == 3'd7)) busy_send <= 1'b0;
    end
end

// Выставление разряда посылки, готовой на передачу
always @(posedge clk)
begin
    if (busy_send) begin
        DO1 <= word_manchester[count_bit];
        DO0 <= ~word_manchester[count_bit]; end
    else begin
        DO1 <= 1'b0;
        DO0 <= 1'b0; 
    end
end

endmodule