`timescale 1ns/1ps
module order_manager (
    input logic clk,
    input logic rst,

    input logic cmd_valid,
    input logic [1:0] cmd_type,

    input logic [31:0] order_id,
    input logic [7:0] symbol_id,
    input logic side,
    input logic [31:0] price,
    input logic [31:0] quantity,
    input logic scan_enable,
    input logic [3:0] scan_addr,



    output logic scan_valid,
    output logic scan_side,
    output logic [31:0] scan_price, 
    output logic cmd_ready,
    output logic busy,
    output logic done,
    output logic error
);
// declarations
    localparam logic [1:0] ADD    = 2'b00;
    localparam logic [1:0] CANCEL = 2'b01;
    localparam logic [1:0] TRADE  = 2'b10;
    logic read_valid;
    logic [31:0] read_order_id;
    logic [7:0] read_symbol_id;
    logic read_side;
    logic [31:0] read_price;
    logic [31:0] read_quantity;

    logic write_enable;
    logic [3:0] write_address;
    logic write_valid;

    logic [1:0]  cmd_type_q;
    logic [31:0] order_id_q;
    logic [7:0]  symbol_id_q;
    logic        side_q;
    logic [31:0] price_q;
    logic [31:0] quantity_q;
    logic [31:0] store_order_id;
    logic [7:0]  store_symbol_id;
    logic        store_side;
    logic [31:0] store_price;
    logic [31:0] store_quantity;
    logic [3:0] search_addr;
    logic free_found_q;
    logic [3:0] free_addr_q;
    logic error_q;
    assign cmd_ready = (state == IDLE) && !scan_enable && !rst;
    assign scan_valid = read_valid;
    assign scan_side = read_side;
    assign scan_price = read_price;

order_store store (
    .clk(clk),
    .rst(rst),

    .write_enable(write_enable),
    .write_address(write_address),
    .valid(write_valid),

    .order_id(store_order_id),
    .symbol_id(store_symbol_id),
    .side(store_side),
    .price(store_price),
    .quantity(store_quantity),

    .read_addr(scan_enable ? scan_addr : search_addr),

    .read_valid(read_valid),
    .read_order_id(read_order_id),
    .read_symbol_id(read_symbol_id),
    .read_side(read_side),
    .read_price(read_price),
    .read_quantity(read_quantity)
);

typedef enum logic [1:0] {
    IDLE,
    SEARCH,
    WRITE,
    DONE
} state_t;


state_t state, next_state;


always_ff @(posedge clk) begin
    if (rst) begin
        error_q <= 1'b0;
    end
    else if (state == IDLE && cmd_valid && cmd_ready) begin
        error_q <= 1'b0;
    end
    else if (state == SEARCH &&
             next_state == DONE) begin
        error_q <= 1'b1;
    end
end

// rst logic - next state
always_ff @ (posedge clk) begin
    if (rst) begin
    state <= IDLE;
    end 
    else begin
    state <= next_state;
    end
    end

// increments addr while finding the correct address during search
always_ff @(posedge clk) begin
    if (rst || state == IDLE) begin
        search_addr <= 4'd0;
    end
    else begin
        if (state == SEARCH && 
            next_state == SEARCH && 
            search_addr != 4'd15) begin 
            search_addr <= search_addr + 4'd1;
        end 
        end
    end

// stores everything in its _q register so we dont assign a wrong value
// while in IDLE
always_ff @(posedge clk) begin
    if (rst) begin 
        order_id_q <= 0;
        symbol_id_q <= 0;
        cmd_type_q <= 0;
        side_q <= 0;
        price_q <= 0;
        quantity_q <= 0;
    end
    else if (state == IDLE && cmd_valid && cmd_ready) begin
        order_id_q  <=  order_id;
        symbol_id_q <= symbol_id;
        cmd_type_q    <=  cmd_type;
        side_q      <=      side;
        price_q     <=     price;
        quantity_q  <=  quantity;
    end
    end

// if ADD encounters an empty slot, it remembers the address and searches 
// for duplicate IDs
always_ff @(posedge clk) begin
    if (rst || state == IDLE) begin
        free_found_q <= 1'b0;
        free_addr_q <= 4'd0;
    end
    else if (state == SEARCH &&
             cmd_type_q == ADD &&
             !read_valid &&
             !free_found_q) begin

        free_found_q <= 1'b1;
        free_addr_q <= search_addr;
    end
    end

// while in WRITE (ADD OR CANCEL)
always_comb begin 
    write_enable = 1'b0;
    write_address = (cmd_type_q == ADD) 
                    ? free_addr_q
                    : search_addr;

    write_valid = 1'b0;

    store_order_id = order_id_q;
    store_symbol_id = symbol_id_q;
    store_side = side_q;
    store_price = price_q;
    store_quantity = quantity_q;

     if (state == WRITE) begin

        case (cmd_type_q)

            ADD: begin
                write_enable = 1'b1;
                write_valid = 1'b1;
            end

            CANCEL: begin
                write_enable = 1'b1;
                write_valid = 1'b0;

                store_order_id = read_order_id;
                store_symbol_id = read_symbol_id;
                store_side = read_side;
                store_price = read_price;
                store_quantity = read_quantity;
            end

            TRADE : begin
            if (quantity_q > 0 &&
            quantity_q <= read_quantity) begin

                write_enable = 1'b1;

                store_order_id = read_order_id;
                store_symbol_id = read_symbol_id;
                store_side = read_side;
                store_price = read_price;

                store_quantity = read_quantity - quantity_q;
                write_valid = (store_quantity != 0);
            end
            end

            default: begin
                write_enable = 1'b0;
            end

        endcase
    end
    end

// rest of FSM 
always_comb begin 

    next_state = state;

    case    (state)

    IDLE : begin
     if (cmd_valid && cmd_ready) begin
     next_state = SEARCH;
     end 
        else begin
     next_state = IDLE;
     end
    end

    SEARCH: begin
        case (cmd_type_q)

        ADD: begin
            if (quantity_q == 0 ||
                (read_valid &&
                 read_order_id == order_id_q)) begin

                next_state = DONE; // Error
            end
            else if (search_addr == 4'd15) begin
                if (free_found_q || !read_valid)
                    next_state = WRITE;
                else
                    next_state = DONE; // Memory full
            end
            else begin
                next_state = SEARCH;
            end
        end

        CANCEL, TRADE: begin
            if (read_valid &&
                read_order_id == order_id_q) begin

                if (cmd_type_q == TRADE &&
                    (quantity_q == 0 ||
                     quantity_q > read_quantity))
                    next_state = DONE; // Invalid trade
                else
                    next_state = WRITE;
            end
            else if (search_addr == 4'd15)
                next_state = DONE; // Not found
            else
                next_state = SEARCH;
        end

        default: begin
            next_state = DONE; // Invalid command
        end

     endcase
        end


    WRITE : begin
    next_state = DONE;
    end

    DONE : begin 
    next_state = IDLE;
    end

    default : begin 
    next_state = IDLE;
    end

    endcase
end


assign busy = (state == SEARCH   || state == WRITE);
assign done = (state == DONE);
assign error = (state == DONE) && error_q;




endmodule