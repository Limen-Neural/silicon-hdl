// SPDX-License-Identifier: MIT OR Apache-2.0
// NeuronParamRam.sv
// Canonical source: spikenaut-core-sv/rtl
// Per-neuron parameter RAM (single value per address, e.g. threshold or leak for a neuron).
// gh-14 5u3.6/5u3.7 (comment 5447): header now matches impl (stores ONE param per addr;
// multiple param types like thresh/leak/weight use separate RAM instances or addressing in caller).
// Optional INIT_FILE: Q8.8 hex via $readmemh. Prefer SV `parameter string`
// over bare untyped defaults (tool-specific sizing). Default "NONE" = no load.
// $fopen precheck is sim-only; synthesis keeps $readmemh.

module NeuronParamRam #(
    parameter int    ADDR_WIDTH  = 8,
    parameter int    PARAM_WIDTH = 16,
    parameter string INIT_FILE   = "NONE"
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   we,
    input  logic [ADDR_WIDTH-1:0]  addr,
    input  logic [PARAM_WIDTH-1:0] din,
    output logic [PARAM_WIDTH-1:0] dout
);

    (* ram_style = "block" *) logic [PARAM_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    // $readmemh loads min(file lines, mem depth); pair INIT_FILE size with ADDR_WIDTH.
    initial begin
        if (INIT_FILE != "NONE" && INIT_FILE != "") begin
`ifndef SYNTHESIS
            begin : init_file_check
                int fd;
                fd = $fopen(INIT_FILE, "r");
                if (fd == 0) begin
                    $error("NeuronParamRam: INIT_FILE '%s' not found or cannot be opened", INIT_FILE);
                    $fatal(1);
                end
                $fclose(fd);
            end
`endif
            $readmemh(INIT_FILE, mem);
        end
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
