// UartTx.sv
// Canonical source: spikenaut-bridge-sv/rtl
// UART transmitter

module UartTx #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] data,
    input  logic       send,
    output logic       tx,
    output logic       busy
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
            tx       <= 1'b1;
            busy     <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    if (send) begin
                        shift_reg <= data;
                        state     <= START;
                        clk_cnt   <= '0;
                        busy      <= 1'b1;
                    end
                end
                START: begin
                    tx <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        state   <= DATA;
                        clk_cnt <= '0;
                        bit_idx <= '0;
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end
                DATA: begin
                    tx <= shift_reg[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= '0;
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
                    tx <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
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
