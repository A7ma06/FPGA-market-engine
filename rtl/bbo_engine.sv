`timescale 1ns/1ps
module bbo_engine (
    input logic rst,
    input logic clk,
    input logic start,
    input logic [31:0] read_price,
    input logic read_valid,
    input logic read_side,

    output logic [3:0] scan_addr,
    output logic [31:0] best_bid,
    output logic [31:0] best_ask,
    output logic best_bid_valid,
    output logic best_ask_valid,
    output logic done
);
typedef enum logic [1:0] { 
    IDLE,
    SCAN,
    DONE
 } state_t;
    state_t state, next_state;

// best bid
always_ff @(posedge clk) begin
    if (rst || (state == IDLE && start)) begin
        best_bid <= 32'd0;
    end
    else if (read_price > best_bid &&
            read_valid &&
            read_side == 1 &&
            state == SCAN) begin
        best_bid <= read_price;
    end
    end
// best ask
always_ff @(posedge clk) begin
    if (rst || (state == IDLE && start)) begin
        best_ask <= 32'hFFFFFFFF;
    end
    else if (read_price < best_ask &&
            read_valid &&
            read_side == 0 &&
            state == SCAN) begin
        best_ask <= read_price;
    end
    end
// state declaration
always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
    end
        else begin
            state <= next_state;
        end
    end
// scan_addr increment
always_ff @(posedge clk) begin
    if (rst || state == IDLE) begin
        scan_addr <= 4'd0;
    end
        else if (state == SCAN &&
                scan_addr != 4'd15) begin
        scan_addr <= scan_addr + 4'd1 ;
        end
    end
// flag to make sure we r using a valid value not inital value
always_ff @(posedge clk) begin
    if(rst || (state == IDLE && start)) begin
        best_ask_valid <= 0;
    end else if(state == SCAN &&
             (read_valid == 1 &&
              read_side == 0))
        best_ask_valid <= 1'b1;
    
    end

always_ff @(posedge clk) begin
    if(rst || (state == IDLE && start)) begin
        best_bid_valid <= 0;
    end else if(state == SCAN &&
             (read_valid == 1 &&
              read_side == 1))
        best_bid_valid <= 1'b1;
    
    end

// fsm
always_comb begin
    next_state = state;

    case (state) 


    IDLE: begin
        if (start == 1) begin
            next_state = SCAN;
        end
        else begin 
            next_state = IDLE;
        end
        end

    SCAN: begin
        
    if (scan_addr == 4'd15)
        next_state = DONE;
    else begin
        next_state = SCAN;
        end
        end

    DONE: begin
        next_state = IDLE;
    end


    default: next_state = IDLE;


    endcase
    end
  assign done = (state == DONE);

endmodule