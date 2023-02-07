module mem_dev5 
# ( parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 5
) (
  input  logic [DATA_WIDTH-1:0] data,       
  input  logic [ADDR_WIDTH-1:0] rdaddress, 
  input  logic [ADDR_WIDTH-1:0] wraddress,
  input  logic                  wren,     
  input  logic                  rdclock,
  input  logic                  wrclock,
  output logic [DATA_WIDTH-1:0] q
);
    
logic [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];
    
always_ff @(posedge wrclock) if (wren) ram[wraddress] <= data;
    
always_ff @(posedge rdclock) q <= ram[rdaddress];
    
endmodule