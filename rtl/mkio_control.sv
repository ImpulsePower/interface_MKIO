module mkio_control 
# ( parameter [4:0] ADDRESS   = 5'd1,
    parameter [4:0] SUBADDR_2 = 5'd2, 
    parameter [4:0] SUBADDR_4 = 5'd4
) (
    input  logic        clk,
    input  logic        reset,
    // Receiver interface
    input  logic        rx_done,
    input  logic [15:0] rx_data,
    input  logic        rx_cd,
    input  logic        p_error,
    // Transmitter interface
    output logic        tx_ready,
    output logic [15:0] tx_data,
    output logic        tx_cd,
    input  logic        tx_busy,
    // MEM_DEV 2 interface
    input  logic        clk_rd_dev2,
    input  logic [4:0]  addr_rd_dev2,
    output logic [15:0] out_data_dev2,
    output logic        busy_dev2,
    // MEM_DEV 4 interface
    input  logic        clk_wr_dev4,
    input  logic [4:0]  addr_wr_dev4,
    input  logic [15:0] in_data_dev4,
    input  logic        we_dev4,
    output logic        busy_dev4
);

// Sub-module of remote terminals (RT) 2
logic [15:0] tx_data_dev2; 
logic tx_cd_dev2, tx_ready_dev2, dev2;

device2 device2_sb (
    .clk      (clk),
    .reset    (reset),
    .start    (dev2),
    .rx_done  (rx_done),
    .rx_data  (rx_data),
    .p_error  (p_error),
    .tx_data  (tx_data_dev2),
    .tx_cd    (tx_cd_dev2),
    .tx_ready (tx_ready_dev2),
    .tx_busy  (tx_busy),
    .addr_rd  (addr_rd_dev2),
    .clk_rd   (clk_rd_dev2),
    .out_data (out_data_dev2),
    .busy     (busy_dev2)
);

// Sub-module of remote terminals (RT) 4
logic [15:0] tx_data_dev4; 
logic tx_cd_dev4, tx_ready_dev4, dev4;

device4 device4_sb (
    .clk      (clk),
    .reset    (reset),
    .start    (dev4),
    .rx_data  (rx_data),
    .p_error  (p_error),
    .tx_data  (tx_data_dev4),
    .tx_cd    (tx_cd_dev4),
    .tx_ready (tx_ready_dev4),
    .tx_busy  (tx_busy),
    .addr_wr  (addr_wr_dev4),
    .clk_wr   (clk_wr_dev4),
    .in_data  (in_data_dev4),
    .we       (we_dev4),
    .busy     (busy_dev4)
);

// Message to the channel controller that the command word (CW) came
bit wr_rd;
assign wr_rd = rx_data[10];
assign dev2 = ((~rx_cd)
            &(rx_data[15:11] == ADDRESS)
            &(rx_data[9:5] == SUBADDR_2)
            &(rx_done)
            &(~wr_rd));

assign dev4 = ((~rx_cd)
            &(rx_data[15:11] == ADDRESS)
            &(rx_data[9:5] == SUBADDR_4)
            &(rx_done)
            &(wr_rd));

// Mux for the transmitter
logic sel = 1'bx;

always_ff @ (posedge clk) begin
    case ({dev2, dev4})  
        2'b10:sel = 1'b0;  
        2'b01:sel = 1'b1;
    endcase
end

always_comb begin : tx_interface
    tx_data  = (sel) ? tx_data_dev4  : tx_data_dev2;
    tx_cd    = (sel) ? tx_cd_dev4    : tx_cd_dev2;
    tx_ready = (sel) ? tx_ready_dev4 : tx_ready_dev2;
end

endmodule
 