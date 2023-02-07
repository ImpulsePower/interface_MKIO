// `include "../rtl/mkio.sv"

`timescale 1ns/1ps

module tb ();

logic clk;
logic reset;
//1553B - channel A
logic        DI1A, DI0A;
logic        DO1A, DO0A;
logic        RX_STROB_A;
logic        TX_INHIBIT_A;
//1553B - channel B
logic        DI1B, DI0B;
logic        DO1B, DO0B;
logic        RX_STROB_B;
logic        TX_INHIBIT_B;
//MEM DEV 3 interface
logic [4:0]   addr_rd_dev3;
logic         clk_rd_dev3;
logic [15:0] out_data_dev3;
logic         busy_dev3;
//MEM DEV 5 interface
logic [4:0]   addr_wr_dev5;
logic [15:0]  in_data_dev5;
logic         clk_wr_dev5;
logic         we_dev5;
logic         busy_dev5;

mkio DUT (
    clk, reset,
    //MKIO interface - channel A
    DI1A, DI0A, DO1A, DO0A,
    RX_STROB_A,TX_INHIBIT_A,
    //MKIO interface - channel B
    DI1B, DI0B, DO1B, DO0B,
    RX_STROB_B, TX_INHIBIT_B,
    //Memories interface
    addr_rd_dev3, clk_rd_dev3, out_data_dev3, busy_dev3,
    addr_wr_dev5, in_data_dev5, clk_wr_dev5, we_dev5, busy_dev5
);

logic [15:0] tb_array_dev3 [0:31];
logic [15:0] tb_array_dev5 [0:31];

task array_init;
    integer i;
    begin
        // $monitor
        $display(" | data test dev3 | data test dev5 ");
        $display("******************|*************");
        for (i = 0; i <= 31; i = i + 1) begin
            tb_array_dev3[i] = {$random} % (2**16-1);
            tb_array_dev5[i] = {$random} % (2**16-1);
            $display("%d | %h\t\t | %h\t\t", i, tb_array_dev3[i], tb_array_dev5[i]);
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

task read_ram3 ( 
    input logic [4:0] addr
);
    begin
        addr_rd_dev3 = addr;
        #31.25 clk_rd_dev3 = 1'b1;
        #31.25 clk_rd_dev3 = 1'b0;
    end
endtask

task write_ram5 ( 
    input logic [15:0] data, 
    input logic [4:0] addr
 );
    begin
        in_data_dev5 <= data;
        addr_wr_dev5 <= addr;
        we_dev5      <= 1'b1;
        #31.25 clk_wr_dev5 = 1'b1;
        #31.25 clk_wr_dev5 = 1'b0;
        we_dev5      <= 1'b0;
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
        addr_rd_dev3 = 5'd0;
        clk_rd_dev3  = 1'b0;
        in_data_dev5 = 16'd0;
        addr_wr_dev5 = 5'd0;
        clk_wr_dev5  = 1'b0;
        we_dev5 = 1'b0;

        //test data init
        $display("\n");
        $display("*************************");
        $display("*** TEST DATA INIT ***");
        $display("*************************");
        array_init;

        #10000; //wait 10 us

        //packet for subaddr 3
        $display("\n");
        $display("*************************");
        $display("*** TESTING SUBADDR 3 ***");
        $display("*************************");
        word_transmit (1,{5'd1,1'b0,5'd3,5'd7});
        $display($time," Transmitted Command Word - ADDRESS 1, SUBADDRESS 3, WORD 7");
        for (i=0; i<7; i=i+1) begin
            word_transmit(0,tb_array_dev3[i]);
            $display($time," Transmitted Data Word - DATA %h", tb_array_dev3[i]);
        end

        #30000; //wait 30 us

        //read mem_dev3
        $display("\n");
        for (i=0; i<7; i=i+1) begin
            read_ram3(i);
            $display("Read MEM_DEV3, addr = %d, data = %h", i, out_data_dev3);
        end

        #10000; //wait 10 us

        $display("\n");
        $display("************************");
        $display("***TESTING SUBADDR 5 ***");
        $display("************************");
        //write mem_dev5
        for (i=0; i<5; i=i+1) begin
            write_ram5(tb_array_dev5[i],i);
            $display("Write MEM_DEV5, addr = %d, data = %h", i, tb_array_dev5[i]);
        end
        //packet for subaddr 5
        word_transmit (1,{5'd1,1'b1,5'd5,5'd5});
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
    $dumpvars(0, DUT);
end

endmodule