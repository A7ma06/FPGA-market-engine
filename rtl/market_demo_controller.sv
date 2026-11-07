`timescale 1ns/1ps

module market_demo_controller (
    input  logic         clk,
    input  logic         rst,

    output logic [127:0] in_data,
    output logic         in_valid,
    input  logic         in_ready,

    input  logic         done,
    input  logic         error,
    input  logic [31:0]  best_bid,
    input  logic [31:0]  best_ask,
    input  logic         best_bid_valid,
    input  logic         best_ask_valid,

    output logic         test_busy,
    output logic         test_pass,
    output logic         test_fail
);

    typedef enum logic [1:0] {
        SEND,
        WAIT_RESULT,
        PASS,
        FAIL
    } state_t;

    state_t state;

    logic [2:0]  test_index;
    logic [15:0] timeout_count;

    logic [31:0] expected_bid, expected_ask;
    logic        expected_bid_valid, expected_ask_valid;
    logic        quote_matches;

    localparam logic [15:0] TIMEOUT_LAST = 16'hFFFF;

    // Build the same 128-bit format used by message_parser.
    function automatic logic [127:0] pack_message (
        input logic [1:0]  kind,
        input logic [31:0] id,
        input logic [31:0] price,
        input logic [31:0] quantity,
        input logic        buy_side
    );
        pack_message = {
            kind, 8'd1, id, price, quantity, 21'd0, buy_side
        };
    endfunction

    // Command and expected-result table.
    // test_index stays unchanged until its result has been checked.
    always_comb begin
        in_data            = '0;
        expected_bid       = 32'd0;
        expected_ask       = 32'hFFFFFFFF;
        expected_bid_valid = 1'b0;
        expected_ask_valid = 1'b0;

        case (test_index)
            3'd0: begin
                // ADD BUY ID1 @100, quantity 50.
                in_data = pack_message(2'b00, 1, 100, 50, 1'b1);
                expected_bid       = 100;
                expected_bid_valid = 1'b1;
            end

            3'd1: begin
                // ADD BUY ID2 @105, quantity 20.
                in_data = pack_message(2'b00, 2, 105, 20, 1'b1);
                expected_bid       = 105;
                expected_bid_valid = 1'b1;
            end

            3'd2: begin
                // ADD SELL ID3 @110, quantity 30.
                in_data = pack_message(2'b00, 3, 110, 30, 1'b0);
                expected_bid       = 105;
                expected_ask       = 110;
                expected_bid_valid = 1'b1;
                expected_ask_valid = 1'b1;
            end

            3'd3: begin
                // CANCEL the best buy, ID2.
                in_data = pack_message(2'b01, 2, 0, 0, 1'b0);
                expected_bid       = 100;
                expected_ask       = 110;
                expected_bid_valid = 1'b1;
                expected_ask_valid = 1'b1;
            end

            3'd4: begin
                // TRADE 10 shares of ID3; 20 remain.
                in_data = pack_message(2'b10, 3, 0, 10, 1'b0);
                expected_bid       = 100;
                expected_ask       = 110;
                expected_bid_valid = 1'b1;
                expected_ask_valid = 1'b1;
            end

            3'd5: begin
                // TRADE the remaining 20 shares of ID3.
                in_data = pack_message(2'b10, 3, 0, 20, 1'b0);
                expected_bid       = 100;
                expected_bid_valid = 1'b1;
            end

            default: begin
                // An invalid index is handled as FAIL below.
            end
        endcase
    end

    assign quote_matches =
        (best_bid_valid == expected_bid_valid) &&
        (best_ask_valid == expected_ask_valid) &&
        (best_bid       == expected_bid)       &&
        (best_ask       == expected_ask);

    assign in_valid  = !rst && (state == SEND);
    assign test_busy = !rst &&
                      ((state == SEND) || (state == WAIT_RESULT));
    assign test_pass = !rst && (state == PASS);
    assign test_fail = !rst && (state == FAIL);

    // Sequential controller: all decisions happen on clock edges.
    always_ff @(posedge clk) begin
        if (rst) begin
            state         <= SEND;
            test_index    <= 3'd0;
            timeout_count <= 16'd0;
        end else begin
            case (state)
                SEND: begin
                    if (test_index > 3'd5) begin
                        state <= FAIL;
                    end else if (in_valid && in_ready) begin
                        // Exactly one command has been accepted.
                        timeout_count <= 16'd0;
                        state         <= WAIT_RESULT;
                    end else if (timeout_count == TIMEOUT_LAST) begin
                        state <= FAIL;
                    end else begin
                        timeout_count <= timeout_count + 16'd1;
                    end
                end

                WAIT_RESULT: begin
                    if (done) begin
                        timeout_count <= 16'd0;

                        if (!error && quote_matches) begin
                            if (test_index == 3'd5) begin
                                state <= PASS;
                            end else begin
                                test_index <= test_index + 3'd1;
                                state      <= SEND;
                            end
                        end else begin
                            state <= FAIL;
                        end
                    end else if (timeout_count == TIMEOUT_LAST) begin
                        state <= FAIL;
                    end else begin
                        timeout_count <= timeout_count + 16'd1;
                    end
                end

                PASS: state <= PASS;
                FAIL: state <= FAIL;

                default: state <= FAIL;
            endcase
        end
    end

endmodule