// SynapseRouter.sv
// Canonical source: synapse-link-hdl/src
// Address-event representation (AER) synapse router

module SynapseRouter #(
    parameter int NEURON_ADDR_WIDTH = 8
    // DATA_WIDTH removed (was unused per gh-14 5u3.7 comments 8803/5441).
    // AER is address-only; no data payload width here.
)(
    input  logic                        clk,
    input  logic                        rst_n,
    // Incoming AER packet
    input  logic [NEURON_ADDR_WIDTH-1:0] src_addr,
    input  logic                         src_valid,
    // Outgoing routed spike
    output logic [NEURON_ADDR_WIDTH-1:0] dst_addr,
    output logic                          dst_valid
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dst_addr  <= '0;
            dst_valid <= 1'b0;
        end else begin
            dst_addr  <= src_addr;
            dst_valid <= src_valid;
        end
    end

endmodule
