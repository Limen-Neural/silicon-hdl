// WeightRam.sv
// Canonical source: spikenaut-core-sv/rtl
// Synaptic weight RAM – single-port, synchronous read/write

module WeightRam #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 16
)(
    input  logic                  clk,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

    logic [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];
    end

endmodule
