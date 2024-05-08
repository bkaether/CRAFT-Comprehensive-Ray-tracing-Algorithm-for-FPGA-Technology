`timescale 1ns/1ps

`include "../data_macros.sv"

module ray_bbox_intersect (
    input wire clk,
    input wire rst_n,
    input wire stall,
    input vec3 ray_orig,
    input vec3_18_18 inv_ray_dir,
    input wire [2:0] div_by_zero,
    input bbox box,

    output wire hit,
    output wire signed [48:0] closest_hit_distance
);

    wire signed [28:0] sub_min_x = box.min.x - ray_orig.x;
    wire signed [28:0] sub_max_x = box.max.x - ray_orig.x;
    wire signed [28:0] sub_min_y = box.min.y - ray_orig.y;
    wire signed [28:0] sub_max_y = box.max.y - ray_orig.y;
    wire signed [28:0] sub_min_z = box.min.z - ray_orig.z;
    wire signed [28:0] sub_max_z = box.max.z - ray_orig.z;
    
    wire signed [48:0] mult_result_t0x, mult_result_t0y, mult_result_t0z;
    wire signed [48:0] mult_result_t1x, mult_result_t1y, mult_result_t1z;

    // signals for bounds checking in case ray has a direction has components that are 0
    wire [2:0] outside_bounds;
    assign outside_bounds[0] = (ray_orig.x < box.min.x) | (ray_orig.x > box.max.x);
    assign outside_bounds[1] = (ray_orig.y < box.min.y) | (ray_orig.y > box.max.y);
    assign outside_bounds[2] = (ray_orig.z < box.min.z) | (ray_orig.z > box.max.z);

    reg [2:0] outside_bounds_buf1;
    reg [2:0] outside_bounds_buf2;
    `FF_EN(clk, rst_n, '0, ~stall, outside_bounds_buf1, outside_bounds)
    `FF_EN(clk, rst_n, '0, ~stall, outside_bounds_buf2, outside_bounds_buf1)

    // swap min and max signal based on the ray direction
    wire [2:0] swap;
    assign swap[0] = div_by_zero[0] ? 1'b0 : (inv_ray_dir.x < 0); // x
    assign swap[1] = div_by_zero[1] ? 1'b0 : (inv_ray_dir.y < 0); // y
    assign swap[2] = div_by_zero[2] ? 1'b0 : (inv_ray_dir.z < 0); // z

    // buffer for div by zero signal to use after the 1 cycle latency multiplications
    reg [2:0] div_by_zero_buf1;
    reg [2:0] div_by_zero_buf2;
    `FF_EN(clk, rst_n, '0, ~stall, div_by_zero_buf1, div_by_zero)
    `FF_EN(clk, rst_n, '0, ~stall, div_by_zero_buf2, div_by_zero_buf1)

    // buffer for swap signal to use after the 1 cycle latency multiplications
    reg [2:0] swap_buf;
    `FF_EN(clk, rst_n, '0, ~stall, swap_buf, swap)

    // x axis
    ray_bbox_mult mult_i_0 (
        .CLK(clk),              // input wire CLK
        .A(sub_min_x),          // input wire [28 : 0] A
        .B(inv_ray_dir.x),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t0x)     // output wire [48 : 0] P
    );

    ray_bbox_mult mult_i_1 (
        .CLK(clk),              // input wire CLK
        .A(sub_max_x),          // input wire [28 : 0] A
        .B(inv_ray_dir.x),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t1x)     // output wire [48 : 0] P
    );

    // y axis
    ray_bbox_mult mult_i_2 (
        .CLK(clk),              // input wire CLK
        .A(sub_min_y),          // input wire [28 : 0] A
        .B(inv_ray_dir.y),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t0y)     // output wire [48 : 0] P
    );

    ray_bbox_mult mult_i_3 (
        .CLK(clk),              // input wire CLK
        .A(sub_max_y),          // input wire [28 : 0] A
        .B(inv_ray_dir.y),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t1y)     // output wire [48 : 0] P
    );

    // z axis
    ray_bbox_mult mult_i_4 (
        .CLK(clk),              // input wire CLK
        .A(sub_min_z),          // input wire [28 : 0] A
        .B(inv_ray_dir.z),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t0z)     // output wire [48 : 0] P
    );

    ray_bbox_mult mult_i_5 (
        .CLK(clk),              // input wire CLK
        .A(sub_max_z),          // input wire [28 : 0] A
        .B(inv_ray_dir.z),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t1z)     // output wire [48 : 0] P
    );

    // set mult result to +/-infinity if there is division by 0
    wire signed [48:0] t0x = div_by_zero_buf1[0] ? `NEGATIVE_INFINITY_49 : mult_result_t0x;
    wire signed [48:0] t1x = div_by_zero_buf1[0] ? `INFINITY_49 : mult_result_t1x;
    wire signed [48:0] t0y = div_by_zero_buf1[1] ? `NEGATIVE_INFINITY_49 : mult_result_t0y;
    wire signed [48:0] t1y = div_by_zero_buf1[1] ? `INFINITY_49 : mult_result_t1y;
    wire signed [48:0] t0z = div_by_zero_buf1[2] ? `NEGATIVE_INFINITY_49 : mult_result_t0z;
    wire signed [48:0] t1z = div_by_zero_buf1[2] ? `INFINITY_49 : mult_result_t1z;

    wire signed [48:0] tmin_x = swap_buf[0] ? t1x : t0x;
    wire signed [48:0] tmax_x = swap_buf[0] ? t0x : t1x;

    wire signed [48:0] tmin_y = swap_buf[1] ? t1y : t0y;
    wire signed [48:0] tmax_y = swap_buf[1] ? t0y : t1y;

    wire signed [48:0] tmin_z = swap_buf[2] ? t1z : t0z;
    wire signed [48:0] tmax_z = swap_buf[2] ? t0z : t1z;

    // flops to break up combinational logic
    reg signed [48:0] tmin_x_reg, tmax_x_reg, tmin_y_reg, tmax_y_reg, tmin_z_reg, tmax_z_reg; 

    `FF_EN(clk, rst_n, '0, ~stall, tmin_x_reg, tmin_x)
    `FF_EN(clk, rst_n, '0, ~stall, tmax_x_reg, tmax_x)
    `FF_EN(clk, rst_n, '0, ~stall, tmin_y_reg, tmin_y)
    `FF_EN(clk, rst_n, '0, ~stall, tmax_y_reg, tmax_y)
    `FF_EN(clk, rst_n, '0, ~stall, tmin_z_reg, tmin_z)
    `FF_EN(clk, rst_n, '0, ~stall, tmax_z_reg, tmax_z)
    
    wire signed [48:0] time_upper_bound;
    wire signed [48:0] time_lower_bound;
    assign time_upper_bound = (tmax_x_reg < tmax_y_reg) ? ((tmax_x_reg < tmax_z_reg) ? tmax_x_reg : tmax_z_reg) : ((tmax_y_reg < tmax_z_reg) ? tmax_y_reg : tmax_z_reg);
    assign time_lower_bound = (tmin_x_reg > tmin_y_reg) ? ((tmin_x_reg > tmin_z_reg) ? tmin_x_reg : tmin_z_reg) : ((tmin_y_reg > tmin_z_reg) ? tmin_y_reg : tmin_z_reg);

    assign hit = ~((time_lower_bound > time_upper_bound) | 
                   (div_by_zero_buf2[0] & outside_bounds_buf2[0]) |
                   (div_by_zero_buf2[1] & outside_bounds_buf2[1]) |
                   (div_by_zero_buf2[2] & outside_bounds_buf2[2]) |
                   (time_lower_bound[48] & time_upper_bound[48]));

    assign closest_hit_distance = hit ? (time_lower_bound[48] ? time_upper_bound : time_lower_bound) : `INFINITY_49; 
    
        
endmodule
