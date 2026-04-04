// Basys3_Top.sv
// Canonical source: spikenaut-soc-sv/rtl
//
// Top-level SoC wrapper for the Basys 3 FPGA board.
// Module name is spikenaut_soc_basys3_top (unique; avoids collision with
// synapse_demo_basys3_top in synapse-link-hdl/examples/basys3/).
//
// RTL dependencies (compiled in lib_core / lib_bridge before this file):
//   spikenaut-core-sv/rtl/LifNeuron.sv
//   spikenaut-core-sv/rtl/WeightRam.sv
//   spikenaut-core-sv/rtl/NeuronParamRam.sv
//   spikenaut-core-sv/rtl/StdpController.sv
//   spikenaut-bridge-sv/rtl/UartRx.sv
//   spikenaut-bridge-sv/rtl/UartTx.sv
//   spikenaut-bridge-sv/rtl/SiliconBridge.sv

module spikenaut_soc_basys3_top (
    input  logic        clk,       // 100 MHz on-board oscillator
    input  logic        rst_n,     // Active-low reset (CPU_RESET button)
    // UART
    input  logic        uart_rx,
    output logic        uart_tx,
    // LEDs (lower 16 bits of spike output bus)
    output logic [15:0] led
);

    // ----------------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------------
    localparam int CLK_FREQ        = 100_000_000;
    localparam int BAUD_RATE       = 115_200;
    localparam int DATA_WIDTH      = 16;
    localparam int PARAM_WIDTH     = 16;
    localparam int WEIGHT_ADDR_W   = 10;
    localparam int NEURON_ADDR_W   = 8;

    // ----------------------------------------------------------------
    // Bridge
    // ----------------------------------------------------------------
    logic [7:0] bridge_rx_data;
    logic       bridge_rx_valid;

    SiliconBridge #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_bridge (
        .clk          (clk),
        .rst_n        (rst_n),
        .uart_rx_pin  (uart_rx),
        .uart_tx_pin  (uart_tx),
        .rx_data      (bridge_rx_data),
        .rx_valid     (bridge_rx_valid),
        .tx_data      (bridge_rx_data),
        .tx_send      (1'b0),
        .tx_busy      ()
    );

    // ----------------------------------------------------------------
    // Neuron parameter RAM
    // ----------------------------------------------------------------
    logic [PARAM_WIDTH-1:0] npram_dout;

    NeuronParamRam #(
        .ADDR_WIDTH  (NEURON_ADDR_W),
        .PARAM_WIDTH (PARAM_WIDTH)
    ) u_npram (
        .clk  (clk),
        .we   (1'b0),
        .addr ('0),
        .din  ('0),
        .dout (npram_dout)
    );

    // ----------------------------------------------------------------
    // Weight RAM
    // ----------------------------------------------------------------
    logic [DATA_WIDTH-1:0] weight_dout;

    WeightRam #(
        .ADDR_WIDTH (WEIGHT_ADDR_W),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_wram (
        .clk  (clk),
        .we   (1'b0),
        .addr ('0),
        .din  ('0),
        .dout (weight_dout)
    );

    // ----------------------------------------------------------------
    // LIF neuron
    // ----------------------------------------------------------------
    logic spike_out;

    LifNeuron #(
        .DATA_WIDTH  (DATA_WIDTH),
        .PARAM_WIDTH (PARAM_WIDTH)
    ) u_neuron (
        .clk       (clk),
        .rst_n     (rst_n),
        .spike_in  (bridge_rx_valid),
        .weight    (weight_dout),
        .threshold (npram_dout),
        .leak      (npram_dout),
        .spike_out (spike_out)
    );

    // ----------------------------------------------------------------
    // STDP controller
    // ----------------------------------------------------------------
    StdpController #(
        .DATA_WIDTH   (DATA_WIDTH),
        .ADDR_WIDTH   (WEIGHT_ADDR_W)
    ) u_stdp (
        .clk            (clk),
        .rst_n          (rst_n),
        .pre_spike      (bridge_rx_valid),
        .post_spike     (spike_out),
        .weight_addr    ('0),
        .weight_in      (weight_dout),
        .weight_we      (),
        .weight_addr_out(),
        .weight_out     ()
    );

    // ----------------------------------------------------------------
    // LED output
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            led <= '0;
        else
            led <= {15'b0, spike_out};
    end

endmodule
