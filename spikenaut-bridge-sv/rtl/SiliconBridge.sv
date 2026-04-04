// SiliconBridge.sv
// Canonical source: spikenaut-bridge-sv/rtl
// Top-level bridge: wraps UartRx and UartTx for spike-stream transport

module SiliconBridge #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int BAUD_RATE = 115_200,
    parameter int DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    // UART physical pins
    input  logic                  uart_rx_pin,
    output logic                  uart_tx_pin,
    // Internal spike-stream interface (receive path)
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic                  rx_valid,
    // Internal spike-stream interface (transmit path)
    input  logic [DATA_WIDTH-1:0] tx_data,
    input  logic                  tx_send,
    output logic                  tx_busy
);

    UartRx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart_rx (
        .clk   (clk),
        .rst_n (rst_n),
        .rx    (uart_rx_pin),
        .data  (rx_data),
        .valid (rx_valid)
    );

    UartTx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart_tx (
        .clk   (clk),
        .rst_n (rst_n),
        .data  (tx_data),
        .send  (tx_send),
        .tx    (uart_tx_pin),
        .busy  (tx_busy)
    );

endmodule
