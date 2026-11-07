module market_board_top (
    input  logic       CLOCK_50,
    input  logic [1:0] KEY,
    output logic [7:0] LED
	 
);
   logic [24:0] blink_count;
   logic        heartbeat;
   logic [1:0] reset_sync;
   logic       rst;
	logic [127:0] demo_data;
	logic demo_valid, demo_ready;
	logic engine_busy, engine_done, engine_error;
	logic [31:0] best_bid, best_ask;
	logic best_bid_valid, best_ask_valid;
	logic test_busy, test_pass, test_fail;
	
	
   assign LED = {
    4'b0000,
    test_busy,   // LED3: tests running
    test_fail,   // LED2: failure, latched until reset
    test_pass,   // LED1: all six checks passed
    heartbeat    // LED0: clock heartbeat
};

	market_demo_controller demo (
    .clk(CLOCK_50),
    .rst(rst),

    .in_data(demo_data),
    .in_valid(demo_valid),
    .in_ready(demo_ready),

    .done(engine_done),
    .error(engine_error),
    .best_bid(best_bid),
    .best_ask(best_ask),
    .best_bid_valid(best_bid_valid),
    .best_ask_valid(best_ask_valid),

    .test_busy(test_busy),
    .test_pass(test_pass),
    .test_fail(test_fail)
);

market_top engine (
    .clk(CLOCK_50),
    .rst(rst),

    .in_data(demo_data),
    .in_valid(demo_valid),
    .in_ready(demo_ready),

    .busy(engine_busy),
    .done(engine_done),
    .error(engine_error),
    .best_bid(best_bid),
    .best_ask(best_ask),
    .best_bid_valid(best_bid_valid),
    .best_ask_valid(best_ask_valid)
);
    // Assert reset immediately; release it through two clocked stages.
    always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0])
        reset_sync <= 2'b11;
        else
        reset_sync <= {reset_sync[0], 1'b0};
        end

assign rst = reset_sync[1];


 always_ff @(posedge CLOCK_50) begin
    if (rst) begin
        blink_count <= 25'd0;
        heartbeat <= 0;
    end else if (blink_count == 25'd24999999) begin
        blink_count <= 0;
        heartbeat <= ! heartbeat; 
    end else begin
        blink_count <= blink_count + 25'd1;
    end
    end

endmodule