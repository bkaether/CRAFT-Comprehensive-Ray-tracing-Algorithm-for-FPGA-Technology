`timescale 1ps/1ps

`include "../data_macros.sv"

module ray_bbox_intersect (
    input wire clk,
    input vec3 ray_orig,
    input vec3 inv_ray_dir,
    input bbox box,
    input range prev_range,

    output logic hit,
    output range range_out
);

    wire signed [23:0] sub_min_x = box.min.x - ray_orig.x;
    wire signed [23:0] sub_max_x = box.max.x - ray_orig.x;
    wire signed [23:0] sub_min_y = box.min.y - ray_orig.y;
    wire signed [23:0] sub_max_y = box.max.y - ray_orig.y;
    wire signed [23:0] sub_min_z = box.min.z - ray_orig.z;
    wire signed [23:0] sub_max_z = box.max.z - ray_orig.z;
    
    wire signed [23:0] mult_result_t0x, mult_result_t0y, mult_result_t0z;
    wire signed [23:0] mult_result_t1x, mult_result_t1y, mult_result_t1z;

    // x axis
    mult_gen_0 mult_i_0 (
        .CLK(clk),
        .A(sub_min_x),
        .B(inv_ray_dir.x),
        .P(mult_result_t0x)
    );

    mult_gen_0 mult_i_1 (
        .CLK(clk),
        .A(sub_max_x),
        .B(inv_ray_dir.x),
        .P(mult_result_t1x)
    );

    // y axis
    mult_gen_0 mult_i_2 (
        .CLK(clk),
        .A(sub_min_y),
        .B(inv_ray_dir.y),
        .P(mult_result_t0y)
    );

    mult_gen_0 mult_i_3 (
        .CLK(clk),
        .A(sub_max_y),
        .B(inv_ray_dir.y),
        .P(mult_result_t1y)
    );

    // z axis
    mult_gen_0 mult_i_4 (
        .CLK(clk),
        .A(sub_min_z),
        .B(inv_ray_dir.z),
        .P(mult_result_t0z)
    );

    mult_gen_0 mult_i_5 (
        .CLK(clk),
        .A(sub_max_z),
        .B(inv_ray_dir.z),
        .P(mult_result_t1z)
    );

    wire [2:0] swap;
    assign swap[0] = inv_ray_dir.x < 0; // x
    assign swap[1] = inv_ray_dir.y < 0; // y
    assign swap[2] = inv_ray_dir.z < 0; // z

    wire signed [23:0] t0_x = swap ? mult_result_t1x : mult_result_t0x;
    wire signed [23:0] t1_x = swap ? mult_result_t0x : mult_result_t1x;

    wire signed [23:0] t0_y = swap ? mult_result_t1y : mult_result_t0y;
    wire signed [23:0] t1_y = swap ? mult_result_t0y : mult_result_t1y;

    wire signed [23:0] t0_z = swap ? mult_result_t1z : mult_result_t0z;
    wire signed [23:0] t1_z = swap ? mult_result_t0z : mult_result_t1z;

    wire signed [23:0] tmin_x = (t0_x > prev_range.min) ? t0_x : prev_range.min;
    wire signed [23:0] tmax_x = (t1_x < prev_range.max) ? t1_x : prev_range.max;

    wire signed [23:0] tmin_y = (t0_y > prev_range.min) ? t0_y : prev_range.min;
    wire signed [23:0] tmax_y = (t1_y < prev_range.max) ? t1_y : prev_range.max;

    wire signed [23:0] tmin_z = (t0_z > prev_range.min) ? t0_z : prev_range.min;
    wire signed [23:0] tmax_z = (t1_z < prev_range.max) ? t1_z : prev_range.max;
    
    // outputs
    assign hit = ~((tmax_x <= tmin_x) | (tmax_y <= tmin_y) | (tmax_z <= tmin_z)); 

    assign range_out.min = (tmin_x > tmin_y) ? ((tmin_x > tmin_z) ? tmin_x : tmin_z) : ((tmin_y > tmin_z) ? tmin_y : tmin_z);
    assign range_out.max = (tmax_x < tmax_y) ? ((tmax_x < tmax_z) ? tmax_x : tmax_z) : ((tmax_y < tmax_z) ? tmax_y : tmax_z);
        
endmodule