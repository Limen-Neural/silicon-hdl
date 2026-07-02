// tb_WeightRam.sv
// Unit testbench for spikenaut-core-sv/rtl/WeightRam.sv
//
// Stimulus is applied and sampled on negedge clk (mid-cycle) to avoid
// race conditions with the DUT's posedge-triggered always_ff block.

`timescale 1ns/1ps

module tb_WeightRam;

    localparam int ADDR_WIDTH = 10;
    localparam int DATA_WIDTH = 16;
    localparam int CLK_PERIOD = 10;

    logic                   clk;
    logic                   we;
    logic [ADDR_WIDTH-1:0]  addr;
    logic [DATA_WIDTH-1:0]  din;
    logic [DATA_WIDTH-1:0]  dout;

    int errors = 0;

    WeightRam #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .clk  (clk),
        .we   (we),
        .addr (addr),
        .din  (din),
        .dout (dout)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic check(input bit cond, input string msg);
        if (!cond) begin
            errors++;
            $display("FAIL: %s", msg);
        end
    endtask

    initial begin
        we   = 1'b0;
        addr = '0;
        din  = '0;
        @(negedge clk);

        // Write a value to address 5
        we   = 1'b1;
        addr = 10'd5;
        din  = 16'hABCD;
        @(negedge clk); // write commits on the posedge just passed
        we = 1'b0;

        // Read back address 5 (dout is registered, one cycle latency)
        addr = 10'd5;
        @(negedge clk);
        check(dout == 16'hABCD, "read-after-write at addr 5 should return written value");

        // Write a different value to address 200
        we   = 1'b1;
        addr = 10'd200;
        din  = 16'h1234;
        @(negedge clk);
        we = 1'b0;

        addr = 10'd200;
        @(negedge clk);
        check(dout == 16'h1234, "read-after-write at addr 200 should return written value");

        // Ensure address 5 retained its value (no cross-talk)
        addr = 10'd5;
        @(negedge clk);
        check(dout == 16'hABCD, "addr 5 should retain its value after unrelated write");

        if (errors == 0) begin
            $display("TB_WEIGHTRAM: ALL TESTS PASSED");
            $finish;
        end else begin
            $display("TB_WEIGHTRAM: %0d TEST(S) FAILED", errors);
            $fatal(1, "TB_WEIGHTRAM: testbench FAILED");
        end
    end

endmodule
