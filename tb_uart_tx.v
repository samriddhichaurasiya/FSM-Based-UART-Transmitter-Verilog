`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// tb_uart_tx.v : self-checking testbench for uart_tx
//
// A monitor process acts as a tiny UART receiver: it waits for the start bit,
// samples every bit in the middle of its period, rebuilds the byte, checks the
// stop bit and compares against the byte that was sent.
// Small CLKS_PER_BIT (16) keeps the simulation short; the RTL works the same
// for 434 (50 MHz / 115200).
// -----------------------------------------------------------------------------
module tb_uart_tx;

    localparam CLKS_PER_BIT = 16;
    localparam CLK_PERIOD   = 10;                       // 100 MHz clock
    localparam BIT_T        = CLKS_PER_BIT * CLK_PERIOD;

    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx;
    wire       busy;
    wire       tx_done;

    reg  [7:0] expected;
    reg  [7:0] received;
    integer    pass_cnt;
    integer    fail_cnt;
    integer    i;   // used by the monitor
    integer    k;   // used by the stimulus

    // Device under test
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx       (tx),
        .busy     (busy),
        .tx_done  (tx_done)
    );

    // Clock
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Waveform dump (open dump.vcd in GTKWave; EDA Playground expects this exact name)
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_uart_tx);
    end

    // Send one byte: wait until idle, then pulse tx_start for one clock
    task send_byte(input [7:0] b);
        begin
            @(posedge clk);
            while (busy) @(posedge clk);
            expected = b;
            tx_data  = b;
            tx_start = 1'b1;
            @(posedge clk);
            tx_start = 1'b0;
            @(posedge tx_done);                         // wait for frame to finish
        end
    endtask

    // Monitor: behaves like a UART receiver and checks every frame
    initial begin
        forever begin
            @(negedge tx);                              // start bit begins
            #(BIT_T/2);                                 // move to middle of start bit
            if (tx !== 1'b0) begin
                $display("[%0t] FAIL: start bit not low", $time);
                fail_cnt = fail_cnt + 1;
            end
            for (i = 0; i < 8; i = i + 1) begin
                #(BIT_T);
                received[i] = tx;                       // LSB first
            end
            #(BIT_T);                                   // middle of stop bit
            if (tx !== 1'b1) begin
                $display("[%0t] FAIL: stop bit not high", $time);
                fail_cnt = fail_cnt + 1;
            end
            if (received === expected) begin
                $display("[%0t] PASS: sent 0x%02h, received 0x%02h", $time, expected, received);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[%0t] FAIL: sent 0x%02h, received 0x%02h", $time, expected, received);
                fail_cnt = fail_cnt + 1;
            end
        end
    end

    // Stimulus
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        tx_start = 1'b0;
        tx_data  = 8'h00;
        expected = 8'h00;
        received = 8'h00;
        rst_n    = 1'b0;
        #(5*CLK_PERIOD);
        rst_n    = 1'b1;
        #(5*CLK_PERIOD);

        // Directed tests (corner cases first)
        send_byte(8'hA5);
        send_byte(8'h3C);
        send_byte(8'h00);
        send_byte(8'hFF);
        send_byte(8'h55);

        // Random tests
        for (k = 0; k < 10; k = k + 1)
            send_byte($random);

        #(3*BIT_T);                                     // let the monitor finish last frame

        $display("----------------------------------------");
        $display("Frames passed: %0d   failed: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("RESULT: ALL TESTS PASSED");
        else               $display("RESULT: TESTS FAILED");
        $display("----------------------------------------");
        $finish;
    end

    // Safety timeout
    initial begin
        #(2_000_000);
        $display("TIMEOUT");
        $finish;
    end

endmodule
