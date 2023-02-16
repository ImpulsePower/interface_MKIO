module reset_sync 
( 
    input  logic clk, 
    input  logic rst,
    output logic reset
);

logic rst_reg, rst_shift;

always_ff @( posedge clk, posedge rst )
    if (rst) 
        {rst_reg, rst_shift} <= 2'b0;
    else 
        {rst_reg, rst_shift} <= {rst_shift, 1'b1};
 
always_ff @( posedge clk ) begin : metastability
    // ! - direct logic of reset, inverse logic of reset: <= rst_reg;
    reset <= !rst_reg;
end

endmodule