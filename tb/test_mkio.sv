`timescale 1ns/1ps

module test_mkio ();

logic        clk;
logic        reset;
//MKIO interface - channel A
logic        DI1A, DI0A;
logic        DO1A, DO0A;
logic        RX_STROB_A;
logic        TX_INHIBIT_A;
//MKIO interface - channel B
logic        DI1B, DI0B;
logic        DO1B, DO0B;
logic        RX_STROB_B;
logic        TX_INHIBIT_B;
//MEM DEV 2 interface
logic [4:0]  addr_rd_dev2;
logic        clk_rd_dev2;
logic [15:0] out_data_dev2;
logic        busy_dev2;
//MEM DEV 4 interface
logic [4:0]  addr_wr_dev4;
logic [15:0] in_data_dev4;
logic        clk_wr_dev4;
logic        we_dev4;
logic        busy_dev4;

mkio DUT (
    .clk           (clk), 
    .reset         (reset),
    //MKIO interface - channel A
    .DI1A          (DI1A), 
    .DI0A          (DI0A), 
    .DO1A          (DO1A), 
    .DO0A          (DO0A),
    .RX_STROB_A    (RX_STROB_A),
    .TX_INHIBIT_A  (TX_INHIBIT_A),
    //MKIO interface - channel B
    .DI1B          (DI1B), 
    .DI0B          (DI0B), 
    .DO1B          (DO1B), 
    .DO0B          (DO0B),
    .RX_STROB_B    (RX_STROB_B), 
    .TX_INHIBIT_B  (TX_INHIBIT_B),
    //MEM DEV 2 interface
    .addr_rd_dev2  (addr_rd_dev2), 
    .clk_rd_dev2   (clk_rd_dev2), 
    .out_data_dev2 (out_data_dev2), 
    .busy_dev2     (busy_dev2),
    //MEM DEV 4 interface
    .addr_wr_dev4  (addr_wr_dev4), 
    .in_data_dev4  (in_data_dev4), 
    .clk_wr_dev4   (clk_wr_dev4), 
    .we_dev4       (we_dev4), 
    .busy_dev4     (busy_dev4)
);

logic [15:0] tb_array_dev2 [0:31];
logic [15:0] tb_array_dev4 [0:31];

task array_init;
    integer i;
    begin
        // $monitor
        $display(" | data test dev2 | data test dev4 ");
        $display("******************|*************");
        for (i = 0; i <= 31; i = i + 1) begin
            tb_array_dev2[i] = {$random} % (2**16-1);
            tb_array_dev4[i] = {$random} % (2**16-1);
            $display("%d | %h\t\t | %h\t\t", i, tb_array_dev2[i], tb_array_dev4[i]);
        end
    end
endtask

task word_transmit ( 
    input logic sync, 
    input logic [15:0] data
 );

    integer i;
    logic [39:0] shift_reg;
    logic parity;

    begin
    //set sync
        if (sync) shift_reg[39:34] = 6'b111000;
        else shift_reg[39:34] = 6'b000111;
        //set field
        for(i=0; i<=15; i=i+1)
            shift_reg[(i*2+2)+: 2] = {data[i],~data[i]};
            //set parity
        parity = 1'b1;
        for(i = 0; i<= 15; i = i + 1) begin
            if (data[i] == 1'b1) parity = ~parity;
            else parity = parity;
        end
        shift_reg[1:0] = {parity, ~parity};
        
        //send
        for(i = 0; i <= 39; i = i + 1) begin
            DI1A = shift_reg[39-i];
            DI0A = ~shift_reg[39-i];
            #500;
        end
        DI1A = 0;
        DI0A = 0;
    end
endtask

task word_receiver;
    integer i;
    logic [39:0] tb_man_reg;
    logic [19:0] tb_data_reg;

    begin
    //input
    for(i = 39; i >= 0; i = i - 1) begin
        tb_man_reg[i] = DO1A;
        #500;
    end
    //decode
    for(i=0; i<=19; i=i+1) tb_data_reg[i] = tb_man_reg[i*2+1];
    //indicate
    if(tb_man_reg[39:34] == 6'b111000)
        $display("Received Status Word. ADDRESS = %d, status bits = %b",
        tb_data_reg[16:12], tb_data_reg[11:1]);
    else if (tb_man_reg[39:34] == 6'b000111)
        $display("Received Data Word. DATA = %h", tb_data_reg[16:1]);
    end
endtask

task read_ram2 ( 
    input logic [4:0] addr
);
    begin
        addr_rd_dev2 = addr;
        #31.25 clk_rd_dev2 = 1'b1;
        #31.25 clk_rd_dev2 = 1'b0;
    end
endtask

task write_ram4 ( 
    input logic [15:0] data, 
    input logic [4:0] addr
 );
    begin
        in_data_dev4 <= data;
        addr_wr_dev4 <= addr;
        we_dev4      <= 1'b1;
        #31.25 clk_wr_dev4 = 1'b1;
        #31.25 clk_wr_dev4 = 1'b0;
        we_dev4      <= 1'b0;
    end
endtask

initial
    begin 
        clk = 0;
        #15.625 
        forever 
        #15.625 clk = !clk;
    end

initial 
    begin
        // 500 microsec
        #500000 $finish;
    end

initial
    begin
        
        reset = 0;
        repeat (10) @(posedge clk);
        reset = 1;
        repeat (10) @(posedge clk);
        reset = 0;
    end

integer i;

initial
    begin
        //init input signals
        {DI1A, DI0A} = {2'b00};
        {DI1B, DI0B} = {2'b00};
        addr_rd_dev2 = 5'd0;
        clk_rd_dev2  = 1'b0;
        in_data_dev4 = 16'd0;
        addr_wr_dev4 = 5'd0;
        clk_wr_dev4  = 1'b0;
        we_dev4 = 1'b0;

        //test data init
        $display("\n");
        $display("*************************");
        $display("*** TEST DATA INIT ***");
        $display("*************************");
        array_init;

        #10000; //wait 10 us

        //package for subaddr 2
        $display("\n");
        $display("*************************");
        $display("*** TESTING SUBADDR 2 ***");
        $display("*************************");
        word_transmit (1,{5'd1,1'b0,5'd2,5'd7});
        $display($time," Transmitted Command Word - ADDRESS 1, SUBADDRESS 2, WORD 7");
        for (i=0; i<7; i=i+1) begin
            word_transmit(0,tb_array_dev2[i]);
            $display($time," Transmitted Data Word - DATA %h", tb_array_dev2[i]);
        end

        #30000; //wait 30 us

        //read mem_dev2
        $display("\n");
        for (i=0; i<7; i=i+1) begin
            read_ram2(i);
            $display("Read MEM_DEV3, addr = %d, data = %h", i, out_data_dev2);
        end

        #10000; //wait 10 us

        $display("\n");
        $display("************************");
        $display("***TESTING SUBADDR 4 ***");
        $display("************************");
        //write mem_dev4
        for (i=0; i<5; i=i+1) begin
            write_ram4(tb_array_dev4[i],i);
            $display("Write MEM_DEV4, addr = %d, data = %h", i, tb_array_dev4[i]);
        end
        //package for subaddr 4
        word_transmit (1,{5'd1,1'b1,5'd4,5'd5});
        #10000;
        $display("\n");
    end

initial
    forever
    if (DO1A ^ DO0A) begin
        word_receiver;
    end
    else begin
        @clk;
    end

initial begin
    $dumpfile("../sim/test_mkio.vcd");
    $dumpvars(0, test_mkio);
end

endmodule