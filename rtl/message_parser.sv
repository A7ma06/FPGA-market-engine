`timescale 1ns/1ps
module message_parser (

input logic             clk,
input logic             rst,

input logic [127:0]     in_data,
input logic             in_valid,



output logic [1:0]      msg_type,
output logic            side,
output logic [7:0]      symbol_id,
output logic [31:0]     order_id,
output logic [31:0]     price,
output logic [31:0]     quantity,
output logic            out_valid,
output logic            in_ready
);


logic [1:0]  TYPE;
logic [7:0] SYMBOL;
logic [31:0] ORDER_ID;
logic [31:0] PRICE;
logic [31:0] QUANTITY;
logic        SIDE; 


assign in_ready = 1'b1;
assign TYPE     = in_data[127:126];
assign SYMBOL   = in_data[125:118];
assign ORDER_ID = in_data[117:86];
assign PRICE    = in_data[85:54];
assign QUANTITY = in_data[53:22];
assign SIDE     = in_data[0];


always_ff @ (posedge clk) begin 

    if(rst) begin 
    msg_type   <= '0;
    side       <= '0;
    symbol_id  <= '0;
    order_id   <= '0;
    price      <= '0;
    quantity   <= '0;
    out_valid  <= '0;
    end
    else if (in_ready && in_valid) begin
   
    msg_type <= TYPE;
    side <= SIDE;
    symbol_id <= SYMBOL;
    order_id <= ORDER_ID;
    price <= PRICE;
    quantity <= QUANTITY;

    out_valid <= 1'b1;
    end

    else begin
     out_valid <= 0;
end
end

endmodule 