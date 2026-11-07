`timescale 1ns/1ps

module market_top (
    input  logic         clk,
    input  logic         rst,

    input  logic [127:0] in_data,
    input  logic         in_valid,
    output logic         in_ready,

    output logic         busy,
    output logic         done,
    output logic         error,

    output logic [31:0]  best_bid,
    output logic [31:0]  best_ask,
    output logic         best_bid_valid,
    output logic         best_ask_valid
);

typedef enum logic [2:0]{
    IDLE,
    DECODE,
    UPDATE,
    SCAN_START,
    SCAN,
    REPORT } state_t;
    state_t state, next_state;

    // Parser → order manager
    logic [1:0]  msg_type;
    logic [7:0]  symbol_id;
    logic [31:0] order_id, price, quantity;
    logic        side;
    logic        parsed_valid, parser_ready;

    // Order manager → controller
    logic cmd_ready;
    logic manager_busy, manager_done, manager_error;

    // Controller / shared store / BBO
    logic        scan_enable, scan_start, scan_done;
    logic [3:0]  scan_addr;
    logic        scan_valid, scan_side;
    logic [31:0] scan_price;

    // BBO working results — published after the scan finishes
    logic [31:0] bid_work, ask_work;
    logic        bid_valid_work, ask_valid_work;

    // Remember the command's error until REPORT
    logic error_q;

    // Defining

    assign in_ready = (state == IDLE && !rst);
    assign busy = (state != IDLE);
    assign done = (state == REPORT && !rst);
    assign scan_start = (state == SCAN_START);
    assign scan_enable = (state == SCAN_START || state == SCAN);


message_parser parser (
    .clk(clk),
    .rst(rst),

    .in_data(in_data),
    .in_valid(in_valid && in_ready),
    .in_ready(parser_ready),

    .msg_type(msg_type),
    .side(side),
    .symbol_id(symbol_id),
    .order_id(order_id),
    .price(price),
    .quantity(quantity),
    .out_valid(parsed_valid)
);
order_manager manager (
    .clk(clk),
    .rst(rst),

    .cmd_valid((state == DECODE) && parsed_valid),
    .cmd_ready(cmd_ready),
    .cmd_type(msg_type),
    .order_id(order_id),
    .symbol_id(symbol_id),
    .side(side),
    .price(price),
    .quantity(quantity),

    .busy(manager_busy),
    .done(manager_done),
    .error(manager_error),

    .scan_enable(scan_enable),
    .scan_addr(scan_addr),
    .scan_valid(scan_valid),
    .scan_side(scan_side),
    .scan_price(scan_price)
);
bbo_engine bbo (
    .clk(clk),
    .rst(rst),
    .start(scan_start),

    .read_price(scan_price),
    .read_valid(scan_valid),
    .read_side(scan_side),
    .scan_addr(scan_addr),

    .best_bid(bid_work),
    .best_ask(ask_work),
    .best_bid_valid(bid_valid_work),
    .best_ask_valid(ask_valid_work),
    .done(scan_done)
);

always_ff @(posedge clk) begin
    if (rst)
    state <= IDLE;
    else begin
        state <= next_state;
    end
 end

assign error = done && error_q;

always_ff @(posedge clk) begin
    if (rst) begin
        error_q        <= 1'b0;
        best_bid       <= 32'd0;
        best_ask       <= 32'hFFFFFFFF;
        best_bid_valid <= 1'b0;
        best_ask_valid <= 1'b0;
    end else begin
        // Begin a new transaction with no saved error.
        if (state == IDLE && in_valid && in_ready)
            error_q <= 1'b0;

        // Preserve the manager's result until top-level completion.
        if (state == UPDATE && manager_done)
            error_q <= manager_error;

        // Publish both sides together after the complete scan.
        if (state == SCAN && scan_done) begin
            best_bid       <= bid_work;
            best_ask       <= ask_work;
            best_bid_valid <= bid_valid_work;
            best_ask_valid <= ask_valid_work;
        end
    end
end


always_comb begin

 next_state = state;
 case (state) 
    

    IDLE: begin
        if (in_valid && in_ready) begin
        next_state = DECODE ;
        end
        end


    DECODE: begin
        if (parsed_valid && cmd_ready) begin
            next_state = UPDATE;
        
        end
     end 


    UPDATE: begin
        if (manager_done) begin
            next_state = SCAN_START;
        end
     end


    SCAN_START: begin
        
        next_state = SCAN;
     end
    

    SCAN: begin
        if (scan_done) begin
            next_state = REPORT;
        end
     end
    

    REPORT: begin
            next_state = IDLE;
        end

    default: next_state = IDLE;

 endcase
 end



endmodule