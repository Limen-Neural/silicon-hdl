// WeightRam.sv
// Canonical source: spikenaut-core-sv/rtl
// Synaptic weight RAM – single-port, synchronous read/write
//
// gh-14 5u3.6 (P1): added rst_n + dout reset (for sim safety + post-config).
// FPGA block RAM content still undefined without explicit INIT or host load
// after reset (weights/params random at power-up unless initialized).
// Consider host "load phase" post-rst before enabling neuron (see Basys3_Top + epic).

module WeightRam #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 16
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:(2**ADDR_WIDTH)-1];

    // No reset on dout to allow dedicated BRAM inference in Xilinx Vivado.
    // (async or even sync reset on the output register often forces LUT/distributed RAM).
    // gh-14 + Codacy/Gemini/Devin BRAM threads. Reset behavior for sim can be
    // handled by explicit preload or by not relying on dout value until after host load.
    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];
    end

endmodule
