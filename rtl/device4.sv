module device4 
# ( parameter [4:0] ADDRESS = 5'd1 ) 
(
    input  logic        clk,
    input  logic        reset,
    input  logic        start,
    // RX INTERFACE
    input  logic [15:0] rx_data,
    input  logic        p_error,
    // TX INTERFACE
    output logic [15:0] tx_data,
    output logic        tx_cd,
    output logic        tx_ready,
    input  logic        tx_busy,
    // MEMORY INTERFACE
    input  logic [4:0]  addr_wr,
    input  logic        clk_wr,
    input  logic [15:0] in_data,
    input  logic        we,
    output logic        busy
);

// Sub-module of memory
mem_dev4 mem_dev4_sb (
    .data        (in_data),
    .read_addr   (addr_rd),
    .write_addr  (addr_wr),
    .we          (we),
    .read_clock  (clk_rd), 
    .write_clock (clk_wr), 
    .q           (out_data)
);

logic [4:0]  addr_rd;
logic [15:0] out_data;
logic [15:0] rd_data;
logic        clk_rd;

logic [4:0] cnt_word;
logic [5:0] cnt_p;

logic [7:0] cnt_pause;

// Delays
logic [7:0] delay_CW_RW = 8'hFF; //8 us
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
    IDLE       = 4'h0,
    INIT       = 4'h1,
    PAUSE_WAIT = 4'h2,
    LOAD_OS    = 4'h3,
    SEND_OS    = 4'h4,
    READ_DATA  = 4'h5,
    PREP_DATA  = 4'h6,
    SEND_WAIT  = 4'h7,
    SEND_DATA  = 4'h8,
    CHECK_NUM  = 4'h9,
    END_WAIT   = 4'hA
}   statetype;
statetype STATE;

always_ff @ (posedge clk, posedge start, posedge reset) begin : state_machine
    
    if (reset) begin
        STATE    <= IDLE;
        cnt_p    <= 6'd0;
        clk_rd   <= 1'b0;
        cnt_word <= 5'd0;
        addr_rd  <= 1'b0;
    end

    else if (start) begin
        STATE    <= INIT;
        cnt_p    <= 6'd0;
        addr_rd  <= 1'b0;
        clk_rd   <= 1'b0;
        cnt_word <= 5'd0;
    end

    else case (STATE)
        // State of waiting for a pulse to start receiving data word
        IDLE:begin
            STATE     <= IDLE;
            tx_ready  <= 1'b0;
            tx_data   <= 16'd0;
            busy      <= 1'b0;
            cnt_pause <= 8'h0;
            addr_rd   <= 1'b0;
        end

        // Save the number of data words (DW)
        INIT:begin
            tx_data  <= 16'd0;
            busy     <= 1'b1;
            STATE    <= PAUSE_WAIT;
            num_word <= rx_data[4:0];
            if (p_error) cnt_p <= cnt_p + 1'b1;
        end

        // Counting the number of cycles, which corresponds to the pause 
        // between the command word (CW) and status word (SW)
        PAUSE_WAIT:begin
            cnt_pause <= cnt_pause + 1'h1;
            if (cnt_pause == delay_CW_RW) 
                STATE <= LOAD_OS;
        end

        // Preparing the status word (device address, status bits)
        LOAD_OS:begin
            STATE   <= SEND_OS;
            tx_cd   <= 1'b0;
            tx_data <= {ADDRESS, | cnt_p, 10'd0};
        end

        // Sending a status word to the channel controller
        SEND_OS:begin
            if (cnt_pause != delay_impulse) begin
                tx_ready  <= 1'b1;
                cnt_pause <= cnt_pause + 1'h1;
            end
            else begin
                cnt_pause <= 8'h0;
                tx_ready  <= 1'b0;
                STATE     <= READ_DATA;
            end      
        end

        // Reading data from RAM
        READ_DATA:begin
            clk_rd <= 1'b1;
            STATE  <= PREP_DATA;
        end

        // Preparation of the data word for transmission to the channel controller
        PREP_DATA:begin
            clk_rd  <= 1'b0;
            tx_cd   <= 1'b1;
            STATE   <= SEND_WAIT;
        end

        // Waiting for the end of sending the previous word to the channel controller
        SEND_WAIT:begin
            if (tx_busy) STATE <= SEND_WAIT;
            else         STATE <= SEND_DATA;    
        end

        // Sending a data word to the channel controller
        SEND_DATA:begin
            if (cnt_pause != delay_impulse) begin
                tx_ready  <= 1'b1;
                tx_data   <= out_data;
                cnt_pause <= cnt_pause + 1'h1;
            end
            else begin
                cnt_pause <= 8'h0;
                tx_ready  <= 1'b0;
                clk_rd    <= 1'b0;
                STATE     <= CHECK_NUM;                
            end      
        end

        // Checking the number of data words sent
        CHECK_NUM:begin
            if (cnt_word != num_word_buf) begin
                addr_rd  <= addr_rd + 1'b1;
                cnt_word <= cnt_word + 1'b1;
                STATE    <= READ_DATA;  
            end
            else begin
                cnt_word <= 5'd0;
                addr_rd  <= 1'b0;
                STATE    <= END_WAIT; 
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
