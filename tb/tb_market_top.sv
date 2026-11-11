`timescale 1ns/1ps
module tb_market_top;

    logic clk = 0;
    always #5 clk = ~clk;

    logic rst;
    logic [127:0] in_data;
    logic in_valid;

    wire in_ready, busy, done, error;
    wire [31:0] best_bid, best_ask;
    wire best_bid_valid, best_ask_valid;
    integer accepted_count = 0;
    integer completed_count = 0;
    integer cycles_to_quote;

    always @(posedge clk) begin
    if (rst) begin
        accepted_count <= 0;
        completed_count <= 0;
    end else begin
        if ((in_valid && in_ready) !== (dut.manager.cmd_valid && dut.manager.cmd_ready))
            $fatal(1, "Input and order manager must accept on the same edge");

        if (in_valid && in_ready)
            accepted_count <= accepted_count + 1;

        if (done)
            completed_count <= completed_count + 1;
    end
    end

    market_top dut (.*);

    // Driving inputs on falling edges, away from the DUT's rising edges.
    task automatic send_message(
        input logic [1:0]  kind,
        input logic [31:0] id,
        input logic [31:0] p,
        input logic [31:0] qty,
        input logic        buy_side,
        input logic        expected_error = 1'b0
    );
        @(negedge clk);
        while (!in_ready)
            @(negedge clk);

        in_data = {
            kind, 8'd1, id, p, qty, 21'd0, buy_side
        };
        in_valid = 1;

        // The intervening rising edge accepts the message.
        @(negedge clk);
        in_valid = 0;
        in_data = 'x;

        cycles_to_quote = 0;
        while (!done) begin
            @(negedge clk);
            cycles_to_quote = cycles_to_quote + 1;
        end

        if (error !== expected_error)
        $fatal(1,
        "Unexpected error: type=%0d id=%0d expected=%b actual=%b",
        kind, id, expected_error, error);

        // Consume the completion cycle before sending another message.
        @(negedge clk);
    endtask

    task automatic check_quote(
        input logic [31:0] expected_bid,
        input logic [31:0] expected_ask,
        input logic        expected_bid_valid,
        input logic        expected_ask_valid
    );
        if (best_bid !== expected_bid ||
            best_ask !== expected_ask ||
            best_bid_valid !== expected_bid_valid ||
            best_ask_valid !== expected_ask_valid)
            $fatal(1,
                "Quote mismatch: bid=%0d valid=%b ask=%0d valid=%b",
                best_bid, best_bid_valid, best_ask, best_ask_valid);
    endtask

    // Stop rather than hang forever if the controller gets stuck.
    initial begin
        #20000;
        $fatal(1, "TIMEOUT: transaction did not complete");
    end

    initial begin
        rst = 1;
        in_valid = 0;
        in_data = 0;

        repeat (2) @(negedge clk);
        rst = 0;

        // ADD buy order 1: price 100, quantity 50.
        send_message(2'b00, 1, 100, 50, 1);
        check_quote(100, 32'hFFFFFFFF, 1, 0);
        $display("PASS: first buy (%0d cycles from acceptance to quote)", cycles_to_quote);

        // ADD a better buy.
        send_message(2'b00, 2, 105, 20, 1);
        check_quote(105, 32'hFFFFFFFF, 1, 0);
        $display("PASS: better buy");

        // ADD sell order 3.
        send_message(2'b00, 3, 110, 30, 0);
        check_quote(105, 110, 1, 1);
        $display("PASS: two-sided book");

        // CANCEL the best buy; order 1 should become best again.
        send_message(2'b01, 2, 0, 0, 0);
        check_quote(100, 110, 1, 1);
        $display("PASS: cancel recalculates bid");

        // TRADE 10 of the sell order's 30 shares.
        send_message(2'b10, 3, 0, 10, 0);
        check_quote(100, 110, 1, 1);
        $display("PASS: partial trade retains ask");

        // TRADE the remaining 20 shares; no sell orders remain.
        send_message(2'b10, 3, 0, 20, 0);
        check_quote(100, 32'hFFFFFFFF, 1, 0);
        $display("PASS: full trade removes ask");

        // Remove the final buy.
        send_message(2'b01, 1, 0, 0, 0);
        check_quote(0, 32'hFFFFFFFF, 0, 0);
        $display("PASS: empty book (%0d cycles from acceptance to quote)", cycles_to_quote);

        // Fill all 16 slots with buy orders.
        for (int i = 0; i < 16; i++) begin
        send_message(2'b00, 100 + i, 200 + i, 10, 1);
        end

        check_quote(215, 32'hFFFFFFFF, 1, 0);
        $display("PASS: all 16 slots filled");

        // Remove the order placed in the last available slot.
        send_message(2'b01, 115, 0, 0, 0);
        check_quote(214, 32'hFFFFFFFF, 1, 0);

        // Reuse the only free slot with a new best bid.
        send_message(2'b00, 999, 300, 10, 1);
        check_quote(300, 32'hFFFFFFFF, 1, 0);
        $display("PASS: final slot reused");

        // Full book: reject another ADD.
        send_message(2'b00, 1000, 400, 10, 1, 1);
        check_quote(300, 32'hFFFFFFFF, 1, 0);
        $display("PASS: full book rejected ADD");

        // Missing order: reject CANCEL.
        send_message(2'b01, 5000, 0, 0, 0, 1);
        check_quote(300, 32'hFFFFFFFF, 1, 0);
        $display("PASS: missing order rejected");

        // Order 999 contains 10 shares: reject a trade of 11.
        send_message(2'b10, 999, 0, 11, 0, 1);
        check_quote(300, 32'hFFFFFFFF, 1, 0);
        $display("PASS: oversized trade rejected");

        // A valid full trade must still work after those errors.
        send_message(2'b10, 999, 0, 10, 0);
        check_quote(214, 32'hFFFFFFFF, 1, 0);
        $display("PASS: recovery after rejected commands");
        // Start with an empty book and reset the counters.
        @(negedge clk);
        rst = 1;
        in_valid = 0;
        repeat (2) @(negedge clk);
        rst = 0;

        // Present the first message.
        while (!in_ready) @(negedge clk);
        in_data = {2'b00, 8'd1, 32'd700, 32'd100,
           32'd10, 21'd0, 1'b1};
        in_valid = 1;

        // First message is accepted on the intervening rising edge.
        @(negedge clk);

        // Immediately present the NEXT message, keeping valid high.
        // Hold it unchanged while the engine processes the first.
        in_data = {2'b00, 8'd1, 32'd701, 32'd105,
           32'd10, 21'd0, 1'b1};

        while (!done) @(negedge clk);
        if (error !== 1'b0)
        $fatal(1, "First held-valid command failed");
        check_quote(100, 32'hFFFFFFFF, 1, 0);

        // Wait for readiness to return, then allow the second handshake.
         while (!in_ready) @(negedge clk);
        @(negedge clk);
           in_valid = 0;

        // Wait for the second result.
        while (!done) @(negedge clk);
        if (error !== 1'b0)
        $fatal(1, "Second held-valid command failed");
        check_quote(105, 32'hFFFFFFFF, 1, 0);

        // Allow the completion counter to observe the done pulse.
        @(negedge clk);
        if (accepted_count !== 2 || completed_count !== 2)
        $fatal(1, "Expected 2 accepts/2 completions, got %0d/%0d",
           accepted_count, completed_count);

        $display("PASS: held-valid backpressure, exactly two transactions");


        // Start another command.
        @(negedge clk);
        while (!in_ready) @(negedge clk);

        in_data = {2'b00, 8'd1, 32'd800, 32'd200,
           32'd10, 21'd0, 1'b1};
        in_valid = 1;

        @(negedge clk);
        in_valid = 0;

        // Interrupt processing before it finishes.
        repeat (4) @(negedge clk);
        rst = 1;
        repeat (2) @(negedge clk);
        rst = 0;

        // Check that the aborted transaction never completes later.
        repeat (50) begin
            @(negedge clk);

            if (done !== 1'b0 || in_ready !== 1'b1 ||
            busy !== 1'b0 || error !== 1'b0)
         $fatal(1, "Incorrect status after reset");

         check_quote(0, 32'hFFFFFFFF, 0, 0);
        end

        // Prove the engine can process fresh work after reset.
        send_message(2'b00, 900, 123, 10, 1);
        check_quote(123, 32'hFFFFFFFF, 1, 0);

        $display("PASS: reset aborts pending work and engine recovers");

        $display("ALL MARKET_TOP BASIC TESTS PASSED");
        $finish;
    end

endmodule