// StdpController.sv
// Canonical source: spikenaut-core-sv/rtl
// Spike-Timing-Dependent Plasticity controller

module StdpController #(
    parameter int DATA_WIDTH   = 16,
    parameter int ADDR_WIDTH   = 10,
    parameter int WINDOW_WIDTH = 8
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   pre_spike,
    input  logic                   post_spike,
    input  logic [ADDR_WIDTH-1:0]  weight_addr,
    input  logic [DATA_WIDTH-1:0]  weight_in,
    output logic                   weight_we,
    output logic [ADDR_WIDTH-1:0]  weight_addr_out,
    output logic [DATA_WIDTH-1:0]  weight_out
);

    logic [WINDOW_WIDTH-1:0] pre_trace;
    logic [WINDOW_WIDTH-1:0] post_trace;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pre_trace       <= '0;
            post_trace      <= '0;
            weight_we       <= 1'b0;
            weight_addr_out <= '0;
            weight_out      <= '0;
        end else begin
            pre_trace  <= pre_spike  ? {WINDOW_WIDTH{1'b1}} : (pre_trace  >> 1);
            post_trace <= post_spike ? {WINDOW_WIDTH{1'b1}} : (post_trace >> 1);
            weight_we       <= pre_spike | post_spike;
            weight_addr_out <= weight_addr;
            if (pre_spike && post_trace != '0)
                // Potentiation – saturate at maximum value
                weight_out <= (weight_in == {DATA_WIDTH{1'b1}}) ?
                              weight_in : (weight_in + 1);
            else if (post_spike && pre_trace != '0)
                // Depression – saturate at zero
                weight_out <= (weight_in == '0) ?
                              weight_in : (weight_in - 1);
            else
                weight_out <= weight_in;
        end
    end

endmodule
