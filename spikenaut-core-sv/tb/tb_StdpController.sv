// tb_StdpController.sv
// Unit testbench for spikenaut-core-sv/rtl/StdpController.sv
//
// Stimulus is applied and sampled on negedge clk (mid-cycle) to avoid
// race conditions with the DUT's posedge-triggered always_ff block.

`timescale 1ns/1ps

module tb_StdpController;

    localparam int DATA_WIDTH   = 16;
    localparam int ADDR_WIDTH   = 10;
    localparam int WINDOW_WIDTH = 8;
    localparam int CLK_PERIOD   = 10;

    logic                    clk;
    logic                    rst_n;
    logic                    pre_spike;
    logic                    post_spike;
    logic [ADDR_WIDTH-1:0]   weight_addr;
    logic [DATA_WIDTH-1:0]   weight_in;
    logic                    weight_we;
    logic [ADDR_WIDTH-1:0]   weight_addr_out;
    logic [DATA_WIDTH-1:0]   weight_out;

    int errors = 0;

    StdpController #(
        .DATA_WIDTH   (DATA_WIDTH),
        .ADDR_WIDTH   (ADDR_WIDTH),
        .WINDOW_WIDTH (WINDOW_WIDTH)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .pre_spike      (pre_spike),
        .post_spike     (post_spike),
        .weight_addr    (weight_addr),
        .weight_in      (weight_in),
        .weight_we      (weight_we),
        .weight_addr_out(weight_addr_out),
        .weight_out     (weight_out)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic check(input logic cond, input string msg);
        if ($isunknown(cond)) begin
            errors++;
            $display("FAIL (unknown state): %s", msg);
        end else if (!cond) begin
            errors++;
            $display("FAIL: %s", msg);
        end
    endtask

    initial begin
        // Reset
        rst_n       = 1'b0;
        pre_spike   = 1'b0;
        post_spike  = 1'b0;
        weight_addr = '0;
        weight_in   = '0;
        repeat (2) @(negedge clk);
        check(weight_we == 1'b0, "weight_we should be 0 after reset");
        check(weight_out == '0, "weight_out should be 0 after reset");
        rst_n = 1'b1;
        @(negedge clk);

        // No change when no spikes
        weight_in = 16'd500;
        @(negedge clk);
        check(weight_out == 16'd500, "weight_out should pass through weight_in when no spikes");

        // Potentiation: post then pre while post_trace active -> weight + 1
        post_spike = 1'b1;
        @(negedge clk);
        post_spike = 1'b0;
        @(negedge clk);

        weight_in   = 16'd100;
        weight_addr = 10'd5;
        pre_spike   = 1'b1;
        @(negedge clk);
        pre_spike = 1'b0;
        check(weight_we == 1'b1, "weight_we should assert on potentiation");
        check(weight_out == 16'd101, "potentiation: weight_out should be 101 (100+1)");
        check(weight_addr_out == 10'd5, "weight_addr_out should echo weight_addr");
        @(negedge clk);
        check(weight_we == 1'b0, "weight_we should deassert after spike cycle");

        // Depression: pre then post while pre_trace active -> weight - 1
        pre_spike = 1'b1;
        @(negedge clk);
        pre_spike = 1'b0;
        @(negedge clk);

        weight_in   = 16'd100;
        weight_addr = 10'd7;
        post_spike  = 1'b1;
        @(negedge clk);
        post_spike = 1'b0;
        check(weight_we == 1'b1, "weight_we should assert on depression");
        check(weight_out == 16'd99, "depression: weight_out should be 99 (100-1)");
        check(weight_addr_out == 10'd7, "weight_addr_out should echo weight_addr");
        @(negedge clk);
        check(weight_we == 1'b0, "weight_we should deassert after spike cycle");

        // No change when traces have decayed (spikes too far apart)
        pre_spike = 1'b1;
        @(negedge clk);
        pre_spike = 1'b0;
        repeat (WINDOW_WIDTH + 1) @(negedge clk);

        weight_in  = 16'd200;
        post_spike = 1'b1;
        @(negedge clk);
        post_spike = 1'b0;
        check(weight_out == 16'd200, "no change when traces have decayed");
        check(weight_we == 1'b0, "weight_we should NOT assert when traces have decayed (no actual weight change)");
        @(negedge clk);
        check(weight_we == 1'b0, "weight_we deasserts after spike cycle");

        // Saturation at max: potentiation at max stays at max
        post_spike = 1'b1;
        @(negedge clk);
        post_spike = 1'b0;
        @(negedge clk);

        weight_in = 16'hFFFF;
        pre_spike = 1'b1;
        @(negedge clk);
        pre_spike = 1'b0;
        check(weight_out == 16'hFFFF, "saturation: potentiation at max stays at max");

        // Saturation at zero: depression at zero stays at zero
        pre_spike = 1'b1;
        @(negedge clk);
        pre_spike = 1'b0;
        @(negedge clk);

        weight_in  = 16'd0;
        post_spike = 1'b1;
        @(negedge clk);
        post_spike = 1'b0;
        check(weight_out == 16'd0, "saturation: depression at zero stays at zero");

        if (errors == 0) begin
            $display("TB_STDPCONTROLLER: ALL TESTS PASSED");
            $finish;
        end else begin
            $display("TB_STDPCONTROLLER: %0d TEST(S) FAILED", errors);
            $fatal(1, "TB_STDPCONTROLLER: testbench FAILED");
        end
    end

endmodule
