`timescale 1ps/1ps

`include "../data_macros.sv"

/*
This module outputs normalized pixel coordinates given pixel x and y values
*/
module pixel_sampler (
    input wire clk,
    input wire rst_n,
    input wire [9:0] pixel_x,   // [0, 799]
    input wire [9:0] pixel_y,   // [0, 599]
    input wire stall,

    output wire [16:0] normalized_x,    // Q1.16
    output wire [16:0] normalized_y     // Q1.16
);

    // prng signals
    wire [15:0] offset_x;   // [0, 1)
    wire [15:0] offset_y;   // [0, 1)

    // prng for x offset
    xor_prng #(
        .SEED(16'h1ACE)
    ) prng_x (
        .clk(clk),
        .rst_n(rst_n),
        .enable(~stall),

        .rand_num(offset_x)
    );

    // prng for y offset
    xor_prng #(
        .SEED(16'hC0DE)
    ) prng_y (
        .clk(clk),
        .rst_n(rst_n),
        .enable(~stall),

        .rand_num(offset_y)
    );

    // random, not normalized pixel sample locations
    wire [25:0] rand_x = {pixel_x, offset_x};   // [0, 800)
    wire [25:0] rand_y = {pixel_y, offset_y};   // [0, 600)

    wire [32:0] mult_result_x;
    wire [32:0] mult_result_y;

    // constant coefficient multiplier with 82 (fixed point representation of pixel width reciprocal
    // with 16 fractional bits)
    pixel_sampler_mult_x pixel_sampler_mult_x_i (
        .CLK(clk),          // input wire CLK
        .A(rand_x),         // input wire [25 : 0] A
        .CE(~stall),        // input wire CE
        .P(mult_result_x)   // output wire [32 : 0] P
    );

    // constant coefficient multiplier with 109 (fixed point representation of pixel height reciprocal
    // with 16 fractional bits)
    pixel_sampler_mult_y pixel_sampler_mult_y_i (
        .CLK(clk),          // input wire CLK
        .A(rand_y),         // input wire [25 : 0] A
        .CE(~stall),        // input wire CE
        .P(mult_result_y)   // output wire [32 : 0] P
    );

    // need to right shift the result back by 16 bits for proper fixed point interpretation
    // these numbers have the format Q1.16
    assign normalized_x = mult_result_x[32:16];
    assign normalized_y = mult_result_y[32:16];
    
endmodule