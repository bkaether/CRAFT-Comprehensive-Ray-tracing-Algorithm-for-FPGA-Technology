`timescale 1ps/1ps

`include "../data_macros.sv"

/*
This module precomputes the inverse of the direction of the generated ray for repeated use when
traversing the BVH

THE LATENCY OF THIS MODULE IS 41 CYCLES

*/
module ray_dir_inverse (
    input wire clk,
    input wire stall,
    input vec3 ray_dir,

    output vec3_18_18 inv_ray_dir,
    output wire [2:0] div_by_zero
);

    // since we are taking an inverse define "one" as a localparam with correct bit length
    localparam signed [17:0] ONE = 18'd65536;   // this is 1 << 2^16, since the divisor will use 16 fractional bits

    // instantiate a division module for each component
    ray_inverse_div_wrapper div_x_i (
        .clk(clk),
        .clk_en(~stall),
        .divisor_tvalid(1'b1),
        .divisor(ray_dir.x),
        .dividend_tvalid(1'b1),
        .dividend(ONE),

        .tvalid(),
        .div_by_zero(div_by_zero[0]),
        .result(inv_ray_dir.x)
    );



    ray_inverse_div_wrapper div_y_i (
        .clk(clk),
        .clk_en(~stall),
        .divisor_tvalid(1'b1),
        .divisor(ray_dir.y),
        .dividend_tvalid(1'b1),
        .dividend(ONE),

        .tvalid(),
        .div_by_zero(div_by_zero[1]),
        .result(inv_ray_dir.y)
    );



    ray_inverse_div_wrapper div_z_i (
        .clk(clk),
        .clk_en(~stall),
        .divisor_tvalid(1'b1),
        .divisor(ray_dir.z),
        .dividend_tvalid(1'b1),
        .dividend(ONE),

        .tvalid(),
        .div_by_zero(div_by_zero[2]),
        .result(inv_ray_dir.z)
    );



endmodule