module mkio_control 
# ( parameter [4:0] ADDRESS = 5'd1,
    parameter [4:0] SUBADDR_3 = 5'd3, 
    parameter [4:0] SUBADDR_5 = 5'd5
) (
    input  logic clk,
    input  logic reset,
    // Приёмник
    input  logic        rx_done,
    input  logic [15:0] rx_data,
    input  logic        rx_cd,
    input  logic        p_error,
    // Передатчик
    output logic        tx_ready,
    output logic [15:0] tx_data,
    output logic        tx_cd,
    input  logic        tx_busy,
    // Память dev3
    input  logic        clk_rd_dev3,
    input  logic [4:0]  addr_rd_dev3,
    output logic [15:0] out_data_dev3,
    output logic        busy_dev3,
    // Память dev5
    input  logic        clk_wr_dev5,
    input  logic [4:0]  addr_wr_dev5,
    input  logic [15:0] in_data_dev5,
    input  logic        we_dev5,
    output logic        busy_dev5
);

// Подмодуль ОУ 3
logic [15:0] tx_data_dev3; 
logic tx_cd_dev3, tx_ready_dev3;

// defparam device3.ADDRESS = ADDRESS;
device3 device3_sb (
    .clk      (clk),
    .reset    (reset),
    .start    (dev3),
    .rx_done  (rx_done),
    .rx_data  (rx_data),
    .p_error  (p_error),
    .tx_data  (tx_data_dev3),
    .tx_cd    (tx_cd_dev3),
    .tx_ready (tx_ready_dev3),
    .tx_busy  (tx_busy),
    .addr_rd  (addr_rd_dev3),
    .clk_rd   (clk_rd_dev3),
    .out_data (out_data_dev3),
    .busy     (busy_dev3)
);

// Подмодуль ОУ 5
logic [15:0] tx_data_dev5; 
logic tx_cd_dev5, tx_ready_dev5;

// defparam device5.ADDRESS = ADDRESS;
device5 device5_sb (
    .clk      (clk),
    .reset    (reset),
    .start    (dev5),
    .rx_data  (rx_data),
    .p_error  (p_error),
    .tx_data  (tx_data_dev5),
    .tx_cd    (tx_cd_dev5),
    .tx_ready (tx_ready_dev5),
    .tx_busy  (tx_busy),
    .addr_wr  (addr_wr_dev5),
    .clk_wr   (clk_wr_dev5),
    .in_data  (in_data_dev5),
    .we       (we_dev5),
    .busy     (busy_dev5)
);

// Сообщение для контроллера канала, что пришло командное слово
// logic wr_rd = rx_data[10];
assign wr_rd = rx_data[10];
assign dev3 = ((~rx_cd)
            &(rx_data[15:11] == ADDRESS)
            &(rx_data[9:5] == SUBADDR_3)
            &(rx_done)
            &(~wr_rd));

assign dev5 = ((~rx_cd)
            &(rx_data[15:11] == ADDRESS)
            &(rx_data[9:5] == SUBADDR_5)
            &(rx_done)
            &(wr_rd));

//Mux for the transmitter
logic sel = 1'b0;
always_ff @ (posedge clk) begin 
    case ({dev3, dev5})  
        2'b10:sel <= 1'b0;  
        2'b01:sel <= 1'b1; 
    endcase
end

assign tx_data  = (sel) ? tx_data_dev5  : tx_data_dev3;
assign tx_cd    = (sel) ? tx_cd_dev5    : tx_cd_dev3;
assign tx_ready = (sel) ? tx_ready_dev5 : tx_ready_dev3;

endmodule