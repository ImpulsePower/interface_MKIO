module mkio (
    input clk,
    input reset,
    // МКИО интерфейс - канал A
    input  DI1A, DI0A, 
    output DO1A, DO0A, 
    output RX_STROB_A, 
    output TX_INHIBIT_A,
    // МКИО интерфейс - канал B (резервный).
    input  DI1B, DI0B, 
    output DO1B, DO0B, 
    output RX_STROB_B,
    output TX_INHIBIT_B,
    // Память ОУ 3
    input  [4:0]  addr_rd_dev3,
    input         clk_rd_dev3,
    output [15:0] out_data_dev3,
    output        busy_dev3,
    // Память ОУ 5
    input [4:0]   addr_wr_dev5,
    input [15:0]  in_data_dev5,
    input         clk_wr_dev5,
    input         we_dev5,
    output        busy_dev5
);

// clocks
wire clk32 = clk;
reg  clk16 = 1'b0;
always @ (posedge clk32) clk16 <= !clk16;

// Совмещение входных потоков от основного и резервного каналов
wire   DI1, DI0, DO1, DO0;
assign DI1  = DI1A | DI1B;
assign DI0  = DI0A | DI0B;
assign DO1A = DO1;
assign DO0A = DO0;
assign DO1B = DO1;
assign DO0B = DO0;

// Разрешение/запрет работы приемника и передатчика в момент
// передачи информации от ОУ на контроллер канала
reg [4:0] ena_reg = 5'd0;

always @ (posedge clk16 or posedge reset)
    if (reset) ena_reg <= 5'd0;
    else ena_reg <= {ena_reg[3:0], tx_busy};
        assign RX_STROB_A   = ~{| ena_reg};
        assign TX_INHIBIT_A = ~{| ena_reg};
        assign RX_STROB_B   = ~{| ena_reg};
        assign TX_INHIBIT_B = ~{| ena_reg};

// Подмодуль последовательной передачи парралельных 
// данных  в виде манчестерского кода по внешнему сигналу
wire tx_ready, tx_cd, tx_busy;
wire [15:0] tx_data;

mkio_transmitter Transmitter (
    .clk       (clk16),
    .reset     (reset),
    .DO1       (DO1), 
    .DO0       (DO0),
    .imp_send  (tx_ready),
    .cd_send   (tx_cd),
    .data_send (tx_data),
    .busy_send (tx_busy)
);

// Подмодуль приёма информации по МКИО, проверяющий корректность  
// посылки, и определяющий какое слово принято (КС или ИС) 
wire rx_cd, rx_done, parity_error;
wire [15:0] rx_data;

mkio_receiver Receiver (
    .clk          (clk16),
    .reset        (reset),
    .DI1          (DI1), 
    .DI0          (DI0),
    .data_get     (rx_data),
    .cd_get       (rx_cd),
    .done         (rx_done),
    .parity_error (parity_error)
);

// Подмодуль управляющего контроллера оконечных устройств
mkio_control RT_control (
    .clk           (clk32),
    .reset         (reset),
    .rx_done       (rx_done),
    .rx_data       (rx_data),
    .rx_cd         (rx_cd),
    .p_error       (parity_error),
    .tx_ready      (tx_ready),
    .tx_data       (tx_data),
    .tx_cd         (tx_cd),
    .tx_busy       (tx_busy),
    .addr_rd_dev3  (addr_rd_dev3),
    .clk_rd_dev3   (clk_rd_dev3),
    .out_data_dev3 (out_data_dev3),
    .busy_dev3     (busy_dev3),
    .in_data_dev5  (in_data_dev5),
    .addr_wr_dev5  (addr_wr_dev5),
    .clk_wr_dev5   (clk_wr_dev5),
    .we_dev5       (we_dev5),
    .busy_dev5     (busy_dev5)
);

endmodule 