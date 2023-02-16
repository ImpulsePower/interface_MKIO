module mkio 
(
    input  logic        clk,
    input  logic        rst,
    // MKIO interface - channel A
    input  logic        DI1A, DI0A, 
    output logic        DO1A, DO0A, 
    output logic        RX_STROB_A, 
    output logic        TX_INHIBIT_A,
    // MKIO interface - channel B (backup)
    input  logic        DI1B, DI0B, 
    output logic        DO1B, DO0B, 
    output logic        RX_STROB_B,
    output logic        TX_INHIBIT_B,
    // MEM_DEV 2 interface
    input  logic [4:0]  addr_rd_dev2,
    input  logic        clk_rd_dev2,
    output logic [15:0] out_data_dev2,
    output logic        busy_dev2,
    // MEM_DEV 4 interface
    input  logic [4:0]  addr_wr_dev4,
    input  logic [15:0] in_data_dev4,
    input  logic        clk_wr_dev4,
    input  logic        we_dev4,
    output logic        busy_dev4
);

// Reset synchronizer sub-module
logic reset;

reset_sync reset_sync_sb (
   .clk     (clk),
   .rst     (rst),
   .reset   (reset) 
);

// Sub-module for serial transmission of Parallel 
// Manchester code data in the form of an external signal
logic tx_ready, tx_cd, tx_busy;
logic [15:0] tx_data;

mkio_transmitter transmitter_sb (
    .clk          (clk16),
    .reset        (reset),
    .DO1          (DO1), 
    .DO0          (DO0),
    .imp_send     (tx_ready),
    .cd_send      (tx_cd),
    .data_send    (tx_data),
    .busy_send    (tx_busy)
);

// Sub-module for receiving information by MKIO, which checks 
// the correctness of parcel, and determines which word is accepted (CW or IC)
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

// Terminal controller submodule
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
    .addr_rd_dev2  (addr_rd_dev2),
    .clk_rd_dev2   (clk_rd_dev2),
    .out_data_dev2 (out_data_dev2),
    .busy_dev2     (busy_dev2),
    .in_data_dev4  (in_data_dev4),
    .addr_wr_dev4  (addr_wr_dev4),
    .clk_wr_dev4   (clk_wr_dev4),
    .we_dev4       (we_dev4),
    .busy_dev4     (busy_dev4)
);

// clocks
logic clk32;
logic clk16 = 1'b0;

assign clk32 = clk;
always_ff @(posedge clk32) clk16 <= !clk16;

// Combination of input streams from the main and backup channels
logic DI1, DI0, DO1, DO0;

always_comb begin : inout_MKIO
    DI1  = DI1A | DI1B;
    DI0  = DI0A | DI0B;
    DO1A = DO1;
    DO0A = DO0;
    DO1B = DO1;
    DO0B = DO0;
end

// Enable/disable receiver and transmitter operation at the moment of 
// Transmission of information from the RT to the channel controller
logic [4:0] ena_reg = 5'd0;

always_ff @(posedge clk16, posedge reset) begin
    if (reset) ena_reg <= 5'd0;
    else ena_reg <= {ena_reg[3:0], tx_busy};
end

always_comb begin : permit_transmitter
    RX_STROB_A   = ~{| ena_reg};
    TX_INHIBIT_A = ~{| ena_reg};
    RX_STROB_B   = ~{| ena_reg};
    TX_INHIBIT_B = ~{| ena_reg};
end

endmodule