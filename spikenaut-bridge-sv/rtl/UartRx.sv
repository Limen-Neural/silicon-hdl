// UartRx.sv
// Canonical source: spikenaut-bridge-sv/rtl
// UART receiver

module UartRx #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    output logic [7:0] data,
    output logic       valid
);

    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t              state;
    logic [$clog2(CLKS_PER_BIT)-1:0] clk_cnt;
    logic [2:0]          bit_idx;
    logic [7:0]          shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            clk_cnt  <= '0;
            bit_idx  <= '0;
            shift_reg <= '0;
            data     <= '0;
            valid    <= 1'b0;
        end else begin
            valid <= 1'b0;
            case (state)
                IDLE: begin
                    if (!rx) begin
                        state   <= START;
                        clk_cnt <= '0;
                    end
                end
                START: begin
                    if (clk_cnt == (CLKS_PER_BIT / 2) - 1) begin
                        state   <= DATA;
                        clk_cnt <= '0;
                        bit_idx <= '0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt            <= '0;
                        shift_reg[bit_idx] <= rx;
                        if (bit_idx == 3'h7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        data  <= shift_reg;
                        valid <= 1'b1;
                        state <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
