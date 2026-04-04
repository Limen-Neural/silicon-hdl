// NeuronParamRam.sv
// Canonical source: spikenaut-core-sv/rtl
// Per-neuron parameter RAM (threshold, leak, reset potential)

module NeuronParamRam #(
    parameter int ADDR_WIDTH  = 8,
    parameter int PARAM_WIDTH = 16
)(
    input  logic                   clk,
    input  logic                   we,
    input  logic [ADDR_WIDTH-1:0]  addr,
    input  logic [PARAM_WIDTH-1:0] din,
    output logic [PARAM_WIDTH-1:0] dout
);

    logic [PARAM_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];
    end

endmodule
