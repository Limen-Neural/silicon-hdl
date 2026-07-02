// tb_NeuronParamRam.sv
// Unit testbench for spikenaut-core-sv/rtl/NeuronParamRam.sv
//
// Stimulus is applied and sampled on negedge clk (mid-cycle) to avoid
// race conditions with the DUT's posedge-triggered always_ff block.

`timescale 1ns/1ps

module tb_NeuronParamRam;

    localparam int ADDR_WIDTH  = 8;
    localparam int PARAM_WIDTH = 16;
    localparam int CLK_PERIOD  = 10;

    logic                    clk;
    logic                    we;
    logic [ADDR_WIDTH-1:0]   addr;
    logic [PARAM_WIDTH-1:0]  din;
    logic [PARAM_WIDTH-1:0]  dout;

    int errors = 0;

    NeuronParamRam #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .PARAM_WIDTH (PARAM_WIDTH)
    ) dut (
        .clk  (clk),
        .we   (we),
        .addr (addr),
        .din  (din),
        .dout (dout)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic check(input logic cond, input string msg);
        if (cond === 1'bx) begin
            errors++;
            $display("FAIL (X state): %s", msg);
        end else if (!cond) begin
            errors++;
            $display("FAIL: %s", msg);
        end
    endtask

    initial begin
        we   = 1'b0;
        addr = '0;
        din  = '0;
        @(negedge clk);

        // Write threshold value to address 3
        we   = 1'b1;
        addr = 8'd3;
        din  = 16'd500;
        @(negedge clk); // write commits on the posedge just passed
        we = 1'b0;

        addr = 8'd3;
        @(negedge clk);
        check(dout == 16'd500, "read-after-write at addr 3 should return written value");

        // Write leak value to address 7
        we   = 1'b1;
        addr = 8'd7;
        din  = 16'd12;
        @(negedge clk);
        we = 1'b0;

        addr = 8'd7;
        @(negedge clk);
        check(dout == 16'd12, "read-after-write at addr 7 should return written value");

        // Ensure address 3 retained its value (no cross-talk)
        addr = 8'd3;
        @(negedge clk);
        check(dout == 16'd500, "addr 3 should retain its value after unrelated write");

        if (errors == 0) begin
            $display("TB_NEURONPARAMRAM: ALL TESTS PASSED");
            $finish;
        end else begin
            $display("TB_NEURONPARAMRAM: %0d TEST(S) FAILED", errors);
            $fatal(1, "TB_NEURONPARAMRAM: testbench FAILED");
        end
    end

endmodule