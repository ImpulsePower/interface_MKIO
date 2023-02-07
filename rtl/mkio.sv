module mkio (
    input  logic clk,
    input  logic reset,
    // МКИО интерфейс - канал A
    input  logic DI1A, DI0A, 
    output logic DO1A, DO0A, 
    output logic RX_STROB_A, 
    output logic TX_INHIBIT_A,
    // МКИО интерфейс - канал B (резервный).
    input  logic DI1B, DI0B, 
    output logic DO1B, DO0B, 
    output logic RX_STROB_B,
    output logic TX_INHIBIT_B,
    // Память ОУ 3
    input  logic [4:0]  addr_rd_dev3,
    input  logic       clk_rd_dev3,
    output logic [15:0] out_data_dev3,
    output logic       busy_dev3,
    // Память ОУ 5
    input  logic [4:0]  addr_wr_dev5,
    input  logic [15:0] in_data_dev5,
    input  logic        clk_wr_dev5,
    input  logic        we_dev5,
    output logic        busy_dev5
);

// Подмодуль последовательной передачи парралельных 
// данных  в виде манчестерского кода по внешнему сигналу
logic tx_ready, tx_cd, tx_busy;
logic [15:0] tx_data;

mkio_transmitter transmitter_sb (
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
logic rx_cd, rx_done, parity_error;
logic [15:0] rx_data;

mkio_receiver receiver_sb (
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
mkio_control control_sb (
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

// clocks
logic clk32;
logic clk16 = 1'b0;
assign clk32 = clk;
always_ff @ (posedge clk32) clk16 <= !clk16;

// Совмещение входных потоков от основного и резервного каналов
logic DI1, DI0, DO1, DO0;
assign DI1  = DI1A | DI1B;
assign DI0  = DI0A | DI0B;
assign DO1A = DO1;
assign DO0A = DO0;
assign DO1B = DO1;
assign DO0B = DO0;

// Разрешение/запрет работы приемника и передатчика в момент
// передачи информации от ОУ на контроллер канала
logic [4:0] ena_reg = 5'd0;

always_ff @ (posedge clk16 or posedge reset)
    if (reset) ena_reg <= 5'd0;
    else ena_reg <= {ena_reg[3:0], tx_busy};

assign RX_STROB_A   = ~{| ena_reg};
assign TX_INHIBIT_A = ~{| ena_reg};
assign RX_STROB_B   = ~{| ena_reg};
assign TX_INHIBIT_B = ~{| ena_reg};

endmodule
 