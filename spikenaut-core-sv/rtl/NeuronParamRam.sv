// NeuronParamRam.sv
// Canonical source: spikenaut-core-sv/rtl
// Per-neuron parameter RAM (single value per address, e.g. threshold or leak for a neuron).
// gh-14 5u3.6/5u3.7 (comment 5447): header now matches impl (stores ONE param per addr;
// multiple param types like thresh/leak/weight use separate RAM instances or addressing in caller).
// (Previously claimed multi-param storage including refrac/weight.)

module NeuronParamRam #(
    parameter int ADDR_WIDTH  = 8,
    parameter int PARAM_WIDTH = 16
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   we,
    input  logic [ADDR_WIDTH-1:0]  addr,
    input  logic [PARAM_WIDTH-1:0] din,
    output logic [PARAM_WIDTH-1:0] dout
);

    (* ram_style = "block" *) logic [PARAM_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    // Use synchronous reset on dout so the rst_n port is connected to logic (avoids
    // synthesis "unused port" warnings per Devin). Provides known '0 after reset in sim.
    // BRAM inference should still work with sync reset.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dout <= '0;
        end else if (we) begin
            mem[addr] <= din;
            dout <= din;
        end else begin
            dout <= mem[addr];
        end
    end

endmodule
