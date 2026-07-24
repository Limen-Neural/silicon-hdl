// SPDX-License-Identifier: MIT OR Apache-2.0
// NeuronParamRam.sv
// Canonical source: spikenaut-core-sv/rtl
// Per-neuron parameter RAM (single value per address, e.g. threshold or leak for a neuron).
// gh-14 5u3.6/5u3.7 (comment 5447): header now matches impl (stores ONE param per addr;
// multiple param types like thresh/leak/weight use separate RAM instances or addressing in caller).
// Optional INIT_FILE: Q8.8 hex via $readmemh. Empty = undefined until host write.

module NeuronParamRam #(
    parameter int    ADDR_WIDTH  = 8,
    parameter int    PARAM_WIDTH = 16,
    parameter string INIT_FILE   = ""
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   we,
    input  logic [ADDR_WIDTH-1:0]  addr,
    input  logic [PARAM_WIDTH-1:0] din,
    output logic [PARAM_WIDTH-1:0] dout
);

    (* ram_style = "block" *) logic [PARAM_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    // Synchronous reset on dout (to use rst_n port and provide known value in sim).
    // Read-first semantics preserved (original contract): on write cycle, dout gets
    // old mem value. gh-14 5u3.6 + Devin feedback on semantics change and unused port.
    // Note: BRAM inference with sync reset on output depends on Vivado settings;
    // attribute is a hint.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dout <= '0;
        end else begin
            if (we)
                mem[addr] <= din;
            dout <= mem[addr];
        end
    end

endmodule
