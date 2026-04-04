// LifNeuron.sv
// Canonical source: spikenaut-core-sv/rtl
// Leaky Integrate-and-Fire neuron model

module LifNeuron #(
    parameter int DATA_WIDTH  = 16,
    parameter int PARAM_WIDTH = 16
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   spike_in,
    input  logic [DATA_WIDTH-1:0]  weight,
    input  logic [PARAM_WIDTH-1:0] threshold,
    input  logic [PARAM_WIDTH-1:0] leak,
    output logic                   spike_out
);

    logic [DATA_WIDTH-1:0] membrane_potential;
    logic [DATA_WIDTH-1:0] decayed;

    assign decayed = membrane_potential - leak[DATA_WIDTH-1:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            membrane_potential <= '0;
            spike_out          <= 1'b0;
        end else begin
            // Reset membrane in the same cycle as the spike to ensure a
            // single-cycle pulse on spike_out.
            if (spike_out)
                membrane_potential <= '0;
            else
                membrane_potential <= spike_in ? (decayed + weight) : decayed;
            spike_out <= !spike_out && (decayed >= threshold[DATA_WIDTH-1:0]);
        end
    end

endmodule
