module device2 
# ( parameter [4:0] ADDRESS = 5'd1 ) 
(
    input  logic        clk,
    input  logic        reset, 
    input  logic        start,
    // RX INTERFACE
    input  logic        rx_done,
    input  logic [15:0] rx_data,
    input  logic        p_error,
    // TX INTERFACE
    output logic [15:0] tx_data,
    output logic        tx_cd,
    output logic        tx_ready,
    input  logic        tx_busy,
    // MEMORY INTERFACE
    input  logic [4:0]  addr_rd,
    input  logic        clk_rd,
    output logic [15:0] out_data,
    output logic        busy
);

// Sub-module of memory
mem_dev2 mem_dev2_sb (
    .data      (in_data),
    .wraddress (addr_wr),
    .wren      (we),
    .rdaddress (addr_rd),
    .wrclock   (clk_wr), 
    .rdclock   (clk_rd), 
    .q         (out_data)
);

logic [4:0]  addr_wr;
logic        clk_wr;
logic        we;
// Receiving data from memory
logic [15:0] in_data;
assign in_data = rx_data;

logic [4:0] cnt_word;
logic [5:0] cnt_p;

logic [7:0] cnt_pause;
// Delays
logic [1:0] delay_impulse = 2'h2; //2 clk

// Calculation of the number of words to be taken (N/COM)
logic [4:0] num_word = 5'd0;
logic [4:0] num_word_buf = 5'd0;

always @ (num_word)
    case (num_word)
        5'd0:    num_word_buf = 5'd31;
        default: num_word_buf = num_word - 1'b1;
    endcase

// List of states of a state machine
typedef enum logic [3:0] {   
    IDLE      = 4'h0,     
    INIT      = 4'h1,  
    DATA_WAIT = 4'h2,
    DATA_SAVE = 4'h3,
    CHECK_NUM = 4'h4,
    LOAD_OS   = 4'h5,  
    SEND_OS   = 4'h6,  
    END_WAIT  = 4'h7
}   statetype;
statetype STATE;

always_ff @ (posedge clk, posedge start, posedge reset) begin : state_machine

    if (reset) begin
        STATE <= IDLE; 
        tx_data  <= 16'd0;
        addr_wr  <= 5'd0;
        we       <= 1'b0;
        clk_wr   <= 1'b0;
        cnt_word <= 5'd0;
        cnt_p    <= 6'd0;
        tx_ready <= 1'b0;
        busy     <= 1'b0;
    end

    else if (start) begin
        STATE <= INIT; 
        addr_wr  <= 5'd0;
        we       <= 1'b1;
        clk_wr   <= 1'b0;
        cnt_word <= 5'd0;
        cnt_p    <= 6'd0;
        tx_ready <= 1'b0;
        busy     <= 1'b1;
    end

    else case (STATE)
        // State of waiting for a pulse to start receiving data word
        IDLE:begin
            STATE     <= IDLE;
            addr_wr   <= 5'd0;
            tx_ready  <= 1'b0;
            tx_data   <= 16'd0;
            tx_cd     <= 1'b0;
            we        <= 1'b0;
            busy      <= 1'b0;
            cnt_pause <= 8'h0;
        end

        // Start of data word processing
        INIT:begin
            STATE    <= DATA_WAIT;
            num_word <= rx_data[4:0];
            if (p_error) cnt_p <= cnt_p + 1'b1;
        end
        
        // Waiting state for the next data word
        DATA_WAIT:begin
            if (rx_done) STATE <= DATA_SAVE;
            else         STATE <= DATA_WAIT;
        end

        // The state of saving of the data word
        DATA_SAVE:begin
            STATE  <= CHECK_NUM;
            clk_wr <= 1'b1;
            if (p_error) cnt_p <= cnt_p + 1'b1;
        end

        // Status of checking the number of data words received
        CHECK_NUM:begin
            clk_wr <= 1'b0;
            if (cnt_word == num_word_buf) begin
                cnt_word <= 5'd0;
                STATE    <= LOAD_OS; 
            end
            else begin
                addr_wr <= addr_wr + 1'b1;
                cnt_word <= cnt_word + 1'b1;
                STATE    <= DATA_WAIT; 
            end
        end

        // Preparing the status word
        LOAD_OS:begin
            STATE   <= SEND_OS;
            tx_cd   <= 1'b0;
        end

        // Sending a status word to the channel controller
        SEND_OS:begin
            tx_ready <= 1'b1;
            tx_data  <= {ADDRESS, | cnt_p, 10'd0};
            if (clk) begin
                cnt_pause <= cnt_pause + 1'h1;
                if (cnt_pause == delay_impulse) begin
                    STATE <= END_WAIT;
                    cnt_pause <= 2'h0;
                    tx_ready  <= 1'b0;
                end      
            end
        end

        // Finishing the transfer of all information to the channel controller
        END_WAIT:begin 
            if (tx_busy) STATE <= END_WAIT;
            else         STATE <= IDLE;
        end

    endcase
end

endmodule
