module enable_sync
(
    input  logic enable_in,
    input  logic clk,
    input  logic reset,
    output logic enable_out
);

logic [2:0] en_sync;

always_ff @(posedge clk, posedge reset) begin : reclocking
    if (reset)
        en_sync <= 0;
    else
        en_sync <= {en_sync[1], en_sync[0], enable_in};
    end

always_ff @(posedge clk) begin : metastability
    enable_out <= en_sync[2];
end
  
endmodule