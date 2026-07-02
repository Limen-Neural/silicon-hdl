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

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            membrane_potential <= '0;
            spike_out          <= 1'b0;
        end else begin
            // Reset membrane in the same cycle as the spike to ensure a
            // single-cycle pulse on spike_out.
            automatic logic [DATA_WIDTH-1:0] next_mem;
            automatic logic [DATA_WIDTH-1:0] decayed_mem;
            automatic logic [DATA_WIDTH-1:0] leak_val;
            automatic logic                  next_spike;

            leak_val = leak[DATA_WIDTH-1:0];

            if (spike_out) begin
                // Reset after spike
                next_mem   = '0;
                next_spike = 1'b0;
            end else begin
                // Apply leak with saturation to prevent underflow
                if (membrane_potential > leak_val)
                    decayed_mem = membrane_potential - leak_val;
                else
                    decayed_mem = '0;

                // Integrate spike input
                if (spike_in)
                    next_mem = decayed_mem + weight;
                else
                    next_mem = decayed_mem;

                // Compare against the freshly-integrated value so a spike is
                // registered as soon as it is crossed (fixes a one-cycle
                // delay bug from comparing the pre-integration value).
                next_spike = (next_mem >= threshold[DATA_WIDTH-1:0]);
            end

            membrane_potential <= next_mem;
            spike_out          <= next_spike;
        end
    end

endmodule
