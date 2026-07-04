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
    input  logic        rst_n,     // Physically active-high button (U18/BTNC/CPU_RESET); inverted below to rst (active-low) for internal use per gh-14 5u3.5 polarity fix. XDC ties directly to this port name.
    // UART
    input  logic        uart_rx,
    output logic        uart_tx,
    // LEDs: mirror received AER addresses on lower 8 bits
    output logic [15:0] led
);

    localparam int CLK_FREQ  = 100_000_000;
    localparam int BAUD_RATE = 115_200;

    // gh-14 5u3.5: inversion in RTL (XDC pin/port rst_n kept; BTNC active-high button).
    logic rst;
    assign rst = ~rst_n;

    // ----------------------------------------------------------------
    // Bridge: UART <-> internal byte stream
    // ----------------------------------------------------------------
    logic [7:0] rx_data;
    logic       rx_valid;

    // tx_data / tx_send driven with FIFO logic below (see gh-14 5u3.4)
    logic [7:0] tx_data;
    logic       tx_send;
    logic       tx_busy;

    SiliconBridge #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_bridge (
        .clk          (clk),
        .rst_n        (rst),
        .uart_rx_pin  (uart_rx),
        .uart_tx_pin  (uart_tx),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .tx_data      (tx_data),
        .tx_send      (tx_send),
        .tx_busy      (tx_busy)
    );
    // gh-14 5u3.2 widths review: synapse variant (no neuron/RAMs); bridge 8b stream only
    // (DATA_WIDTH fixed 8 in SiliconBridge/UARTs; see 5u3.7 for cleanup). No mismatches here.

    // ----------------------------------------------------------------
    // gh-14 5u3.4 (P1 Copilot 3035925438): defer tx_send while tx_busy using a
    // skid/hold buffer. Prevents overwrite of in-flight byte. For burst, last pending
    // is kept (demo rate is low). Addressed Devin/Gemini loss/stale/enq-full races by
    // using explicit skid_valid instead of pointer math.
    // Also addresses Devin one-cycle tx_busy latency race with send_pending.
    // ----------------------------------------------------------------
    logic [7:0] tx_hold;
    logic       hold_valid;
    logic       send_pending;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            tx_hold      <= '0;
            hold_valid   <= 1'b0;
            tx_data      <= '0;
            tx_send      <= 1'b0;
            send_pending <= 1'b0;
        end else begin
            tx_send <= 1'b0;
            send_pending <= tx_send;

            if (!tx_busy && !send_pending) begin
                if (hold_valid) begin
                    tx_data    <= tx_hold;
                    tx_send    <= 1'b1;
                    hold_valid <= 1'b0;
                    if (rx_valid) begin
                        tx_hold    <= rx_data;
                        hold_valid <= 1'b1;
                    end
                end else if (rx_valid) begin
                    tx_data <= rx_data;
                    tx_send <= 1'b1;
                end
            end else if (rx_valid) begin
                // while busy or pending, buffer the latest
                tx_hold    <= rx_data;
                hold_valid <= 1'b1;
            end
        end
    end

    // ----------------------------------------------------------------
    // Synapse router: pass AER address downstream
    // ----------------------------------------------------------------
    logic [7:0] routed_addr;
    logic       routed_valid;

    SynapseRouter #(
        .NEURON_ADDR_WIDTH (8)
    ) u_router (
        .clk       (clk),
        .rst_n     (rst),
        .src_addr  (rx_data),
        .src_valid (rx_valid),
        .dst_addr  (routed_addr),
        .dst_valid (routed_valid)
    );

    // ----------------------------------------------------------------
    // LED output: latch last routed address
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            led <= '0;
        else if (routed_valid)
            led <= {8'b0, routed_addr};
    end

endmodule
