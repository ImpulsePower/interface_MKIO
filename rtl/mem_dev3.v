module mem_dev3 
# ( parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 5
) (
  input      [DATA_WIDTH-1:0] data,       
  input      [ADDR_WIDTH-1:0] rdaddress, 
  input      [ADDR_WIDTH-1:0] wraddress,
  input                       wren,     
  input                       rdclock,
  input                       wrclock,
  output reg [DATA_WIDTH-1:0] q
);
    
reg [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0];
    
always @(posedge wrclock) if (wren) ram[wraddress] <= data;
    
always @(posedge rdclock) q <= ram[rdaddress];
    
endmodule