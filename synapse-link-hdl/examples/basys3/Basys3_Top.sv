// Basys3_Top.sv
// Canonical source: synapse-link-hdl/examples/basys3
//
// Basys 3 demo top for the synapse-link communication layer.
// Module name is synapse_demo_basys3_top (unique; avoids collision with
// spikenaut_soc_basys3_top in spikenaut-soc-sv/rtl/).
//
// RTL dependencies (compiled in lib_bridge before this file):
//   spikenaut-bridge-sv/rtl/UartRx.sv
//   spikenaut-bridge-sv/rtl/UartTx.sv
//   spikenaut-bridge-sv/rtl/SiliconBridge.sv
//   synapse-link-hdl/src/SynapseRouter.sv

module synapse_demo_basys3_top (
    input  logic        clk,       // 100 MHz on-board oscillator
    input  logic        rst_n,     // Active-low reset (CPU_RESET button)
    // UART
    input  logic        uart_rx,
    output logic        uart_tx,
    // LEDs: mirror received AER addresses on lower 8 bits
    output logic [15:0] led
);

    localparam int CLK_FREQ  = 100_000_000;
    localparam int BAUD_RATE = 115_200;

    // ----------------------------------------------------------------
    // Bridge: UART <-> internal byte stream
    // ----------------------------------------------------------------
    logic [7:0] rx_data;
    logic       rx_valid;

    SiliconBridge #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_bridge (
        .clk          (clk),
        .rst_n        (rst_n),
        .uart_rx_pin  (uart_rx),
        .uart_tx_pin  (uart_tx),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .tx_data      (rx_data),
        .tx_send      (rx_valid),
        .tx_busy      ()
    );

    // ----------------------------------------------------------------
    // Synapse router: pass AER address downstream
    // ----------------------------------------------------------------
    logic [7:0] routed_addr;
    logic       routed_valid;

    SynapseRouter #(
        .NEURON_ADDR_WIDTH (8)
    ) u_router (
        .clk       (clk),
        .rst_n     (rst_n),
        .src_addr  (rx_data),
        .src_valid (rx_valid),
        .dst_addr  (routed_addr),
        .dst_valid (routed_valid)
    );

    // ----------------------------------------------------------------
    // LED output: latch last routed address
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            led <= '0;
        else if (routed_valid)
            led <= {8'b0, routed_addr};
    end

endmodule
