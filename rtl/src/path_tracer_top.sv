`timescale 1ns/1ps

`include "../data_macros.sv"

module path_tracer_top (
    input wire sysclk,
    input wire rst_n,
    // input wire start,
    input wire [9:0] pixel_x,   // [0, 799]
    input wire [9:0] pixel_y,   // [0, 599]

    output wire hit_out,
    output wire [15:0] test_data
);

    ray generated_ray;

    // ray generation unit
    generate_ray ray_gen_i (
        .clk(sysclk),
        .rst_n(rst_n),
        .stall(1'b0),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),

        .generated_ray(generated_ray)
    );

    vec3_18_18 inv_ray_dir;
    wire [2:0] div_by_zero;

    // ray inverse calculator
    ray_dir_inverse dir_inverse_i (
        .clk(sysclk),
        .stall(1'b0),
        .ray_dir(generated_ray.dir),

        .inv_ray_dir(inv_ray_dir),
        .div_by_zero(div_by_zero)
    );

    // ray_bbox intersect routine

    // create a temporary const bbox to use for now
    bbox box = bbox_default;
    // range prev_range = range_default;
    // range range_out;
    wire [48:0] nxt_closest_hit_distance;
    reg  [48:0] closest_hit_distance_reg;

    reg  hit_reg;
    wire nxt_hit;

    ray_bbox_intersect ray_box_intersect_i (
        .clk(sysclk),
        .rst_n(rst_n),
        .stall(1'b0),
        .ray_orig(generated_ray.orig),
        .inv_ray_dir(inv_ray_dir),
        .box(box),

        .hit(nxt_hit),
        .closest_hit_distance(nxt_closest_hit_distance)
    );

    `FF_EN(sysclk, rst_n, 1'b0, 1'b1, hit_reg, nxt_hit)
    `FF_EN(sysclk, rst_n, 1'b0, 1'b1, closest_hit_distance_reg, nxt_closest_hit_distance)

    assign hit_out = hit_reg;
    assign test_data = closest_hit_distance_reg[15:0];
    
endmodule