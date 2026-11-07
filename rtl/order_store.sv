`timescale 1ns/1ps
module order_store(
    input logic clk,
    input logic rst,
    input logic write_enable,
    input logic [3:0]  write_address,
    input logic        valid ,    
    input logic [31:0] order_id  ,
    input logic [7:0]  symbol_id ,
    input logic   side      ,
    input logic [31:0] price     ,
    input logic [31:0] quantity ,
    input logic [3:0]  read_addr,


    output logic  read_valid  ,
    output logic [31:0] read_order_id,
    output logic [7:0] read_symbol_id,
    output logic read_side,
    output logic [31:0] read_price,
    output logic [31:0] read_quantity


);

    logic        valid_mem     [0:15];
    logic [31:0] order_id_mem  [0:15];
    logic [7:0]  symbol_id_mem [0:15];
    logic        side_mem      [0:15];
    logic [31:0] price_mem     [0:15];
    logic [31:0] quantity_mem  [0:15];
    integer i;

always_ff @ (posedge clk) begin
    if (rst) begin 
    for(i=0; i<16; i++) begin 
    valid_mem[i] <= 1'b0;
    end
    end

else if (write_enable) begin 

    valid_mem[write_address] <= valid;
    order_id_mem[write_address] <= order_id;
    symbol_id_mem[write_address]   <= symbol_id;
    side_mem[write_address]    <= side ;
    price_mem[write_address]    <= price;
    quantity_mem[write_address] <= quantity;
end
end 

always_comb begin 


 read_order_id = order_id_mem[read_addr];
 read_symbol_id = symbol_id_mem[read_addr];
 read_side = side_mem[read_addr];
 read_price = price_mem[read_addr];
 read_quantity = quantity_mem[read_addr];
 read_valid = valid_mem[read_addr];

end


endmodule 