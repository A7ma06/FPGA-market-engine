`timescale 1ns/1ps
module message_parser #(
    parameter bit REGISTER_OUTPUTS = 1'b1
) (
    input  logic         clk,
    input  logic         rst,
    input  logic [127:0] in_data,
    input  logic         in_valid,

    output logic [1:0]   msg_type,
    output logic         side,
    output logic [7:0]   symbol_id,
    output logic [31:0]  order_id,
    output logic [31:0]  price,
    output logic [31:0]  quantity,
    output logic         out_valid,
    output logic         in_ready
);
    logic [127:0] word;
    assign in_ready = 1'b1;

    generate
        if (REGISTER_OUTPUTS) begin : g_registered
            always_ff @(posedge clk) begin
                if (rst) begin
                    word      <= '0;
                    out_valid <= 1'b0;
                end else if (in_valid) begin
                    word      <= in_data;
                    out_valid <= 1'b1;
                end else begin
                    out_valid <= 1'b0;
                end
            end
        end else begin : g_combinational
            assign word      = in_data;
            assign out_valid = in_valid && !rst;
        end
    endgenerate

    assign msg_type  = word[127:126];
    assign symbol_id = word[125:118];
    assign order_id  = word[117:86];
    assign price     = word[85:54];
    assign quantity  = word[53:22];
    // Bits [21:1] are reserved.
    assign side      = word[0];
endmodule
