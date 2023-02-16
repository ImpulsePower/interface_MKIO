module mem_dev4 
# ( parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 5
) (
  input  logic [DATA_WIDTH-1:0] data,       
  input  logic [ADDR_WIDTH-1:0] read_addr, 
  input  logic [ADDR_WIDTH-1:0] write_addr,
  input  logic                  we,     
  input  logic                  read_clock,
  input  logic                  write_clock,
  output logic [DATA_WIDTH-1:0] q
);
    
logic [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];
    
always_ff @( posedge write_clock ) if (we) ram[write_addr] <= data;
    
always_ff @( posedge read_clock ) q <= ram[read_addr];
    
endmodule