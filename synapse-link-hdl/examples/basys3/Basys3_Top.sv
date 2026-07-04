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
    // gh-14 5u3.4 (P1 Copilot 3035925438 on Basys3_Top:46 synapse): tx_send driven
    // directly by rx_valid without tx_busy check => race/loss during in-flight TX.
    // Use a small FIFO so received bytes cannot overwrite an older pending byte.
    // tx_send is a one-clock pulse issued only when the UART transmitter is idle.
    // If the FIFO fills, preserve queued bytes and count dropped arrivals explicitly.
    // ----------------------------------------------------------------
    localparam int TX_FIFO_DEPTH = 4;
    localparam int TX_FIFO_PTR_W = $clog2(TX_FIFO_DEPTH);
    localparam logic [TX_FIFO_PTR_W:0] TX_FIFO_DEPTH_COUNT = TX_FIFO_DEPTH;

    logic [7:0]                 tx_fifo [TX_FIFO_DEPTH];
    logic [TX_FIFO_PTR_W-1:0]   tx_fifo_wr_ptr;
    logic [TX_FIFO_PTR_W-1:0]   tx_fifo_rd_ptr;
    logic [TX_FIFO_PTR_W:0]     tx_fifo_count;
    logic [15:0]                tx_fifo_drop_count;

    wire tx_fifo_empty = (tx_fifo_count == '0);
    wire tx_fifo_full  = (tx_fifo_count == TX_FIFO_DEPTH_COUNT);
    wire tx_fifo_deq   = !tx_fifo_empty && !tx_busy;
    wire tx_fifo_enq   = rx_valid && (!tx_fifo_full || tx_fifo_deq);
    wire tx_fifo_drop  = rx_valid && tx_fifo_full && !tx_fifo_deq;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            tx_fifo_wr_ptr     <= '0;
            tx_fifo_rd_ptr     <= '0;
            tx_fifo_count      <= '0;
            tx_fifo_drop_count <= '0;
            tx_data            <= '0;
            tx_send            <= 1'b0;
        end else begin
            tx_send <= 1'b0;

            if (tx_fifo_enq) begin
                tx_fifo[tx_fifo_wr_ptr] <= rx_data;
                tx_fifo_wr_ptr          <= tx_fifo_wr_ptr + 1'b1;
            end

            if (tx_fifo_deq) begin
                tx_data        <= tx_fifo[tx_fifo_rd_ptr];
                tx_send        <= 1'b1;
                tx_fifo_rd_ptr <= tx_fifo_rd_ptr + 1'b1;
            end

            unique case ({tx_fifo_enq, tx_fifo_deq})
                2'b10: tx_fifo_count <= tx_fifo_count + 1'b1;
                2'b01: tx_fifo_count <= tx_fifo_count - 1'b1;
                default: tx_fifo_count <= tx_fifo_count;
            endcase

            if (tx_fifo_drop) begin
                tx_fifo_drop_count <= tx_fifo_drop_count + 1'b1;
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
