// -----------------------------------------------------------------------------
// uart_tx.v : UART transmitter, 8 data bits, no parity, 1 stop bit (8N1)
//
// CLKS_PER_BIT = clock frequency / baud rate
//   e.g. 50 MHz clock, 115200 baud -> 50_000_000 / 115200 = 434
//
// Interface
//   tx_start : pulse high for 1 clock (while busy == 0) to begin sending tx_data
//   tx_data  : byte to send (captured when tx_start is accepted)
//   tx       : serial output line (idles high)
//   busy     : high from the moment a byte is accepted until the stop bit ends
//   tx_done  : 1-clock pulse when the stop bit has finished
//
// FSM:  IDLE -> START -> DATA (8 bits, LSB first) -> STOP -> IDLE
// -----------------------------------------------------------------------------
module uart_tx #(
    parameter CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,      // active-low asynchronous reset
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output wire       busy,
    output reg        tx_done
);

    // State encoding
    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;   // counts clocks within one bit period
    reg [2:0]  bit_idx;   // which data bit is being sent (0..7)
    reg [7:0]  data_reg;  // latched copy of tx_data

    assign busy = (state != S_IDLE);

    // Sequential logic: non-blocking assignments (<=) for all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            tx       <= 1'b1;     // line idles high
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            data_reg <= 8'd0;
            tx_done  <= 1'b0;
        end else begin
            tx_done <= 1'b0;      // default: pulse lasts one clock only

            case (state)
                S_IDLE: begin
                    tx      <= 1'b1;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        data_reg <= tx_data;
                        state    <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0;                       // start bit
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        state   <= S_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                S_DATA: begin
                    tx <= data_reg[bit_idx];          // LSB first
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1;                       // stop bit
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        tx_done <= 1'b1;
                        state   <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
