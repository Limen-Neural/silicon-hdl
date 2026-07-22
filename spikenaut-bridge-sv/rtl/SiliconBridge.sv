// SPDX-License-Identifier: MIT OR Apache-2.0
// SiliconBridge.sv
// Canonical source: spikenaut-bridge-sv/rtl
// Top-level bridge: wraps UartRx and UartTx for spike-stream transport
//
// gh-14 5u3.7: DATA_WIDTH propagated to UARTs (default 8 matches serial protocol data bits).
// Documented 8b constraint; no longer misleading. See Uart*/tops.
//
// Protocol layering (see docs/interface-alignment.md, issue #8):
//   - With product/default DATA_WIDTH=8 this is a UART byte pipe
//     (start + DATA_WIDTH data + stop); DATA_WIDTH remains parameterized.
//   - Default BAUD_RATE 115_200 matches silicon-bridge FpgaBridge (serialport).
//   - No opcodes, sync bytes (e.g. host 0xAA), or multi-byte frames here.
//   - Host "SiliconBridge v3.0" framing (0xAA + Q8.8 words + spike bitmap) is an
//     application protocol owned by the SoC/protocol FSM + silicon-bridge host,
//     layered on top of rx_data/rx_valid and tx_data/tx_send/tx_busy.

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
        .BAUD_RATE (BAUD_RATE),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_uart_rx (
        .clk   (clk),
        .rst_n (rst_n),
        .rx    (uart_rx_pin),
        .data  (rx_data),
        .valid (rx_valid)
    );

    UartTx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_uart_tx (
        .clk   (clk),
        .rst_n (rst_n),
        .data  (tx_data),
        .send  (tx_send),
        .tx    (uart_tx_pin),
        .busy  (tx_busy)
    );

endmodule
