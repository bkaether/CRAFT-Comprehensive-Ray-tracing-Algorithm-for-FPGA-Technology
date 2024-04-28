`timescale 1ps/1ps

`include "../data_macros.sv"

/*
This counter module will be used for producing ready-valid signals for pipeline stages with
a known, fixed throguhput. MAX_VAL should always be set to the expected latency of the
pipeline stage.
*/
module ready_valid_counter #(
    parameter WIDTH = 3,
    parameter MAX_VAL = 7
) (
    input wire clk,
    input wire rst_n,
    input wire go,

    output wire done
);

    // counter value
    reg  [WIDTH-1:0] count;
    wire [WIDTH-1:0] nxt_count;
    
    assign nxt_count = done ? '0 : (count + 1'b1);
    
    wire counter_en = ~done | (done & go);

    // counter FF
    `FF_EN(clk, rst_n, (MAX_VAL-1), counter_en, count, nxt_count)

    assign done = (count == (MAX_VAL-1));

endmodule