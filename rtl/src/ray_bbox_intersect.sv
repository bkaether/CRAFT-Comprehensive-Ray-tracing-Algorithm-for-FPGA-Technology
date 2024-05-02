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
    // input range prev_range,

    output wire hit,
    // output range range_out
    output wire [48:0] closest_hit_distance
);

    wire signed [28:0] sub_min_x = box.min.x - ray_orig.x;
    wire signed [28:0] sub_max_x = box.max.x - ray_orig.x;
    wire signed [28:0] sub_min_y = box.min.y - ray_orig.y;
    wire signed [28:0] sub_max_y = box.max.y - ray_orig.y;
    wire signed [28:0] sub_min_z = box.min.z - ray_orig.z;
    wire signed [28:0] sub_max_z = box.max.z - ray_orig.z;
    
    wire signed [48:0] mult_result_t0x, mult_result_t0y, mult_result_t0z;
    wire signed [48:0] mult_result_t1x, mult_result_t1y, mult_result_t1z;

    // buffer for div by zero signal to compare against the correct multiplication result
    reg [2:0] div_by_zero_buf;

    `FF_EN(clk, rst_n, '0, ~stall, div_by_zero_buf, div_by_zero)

    // x axis
    mult_gen_0 mult_i_0 (
        .CLK(clk),              // input wire CLK
        .A(sub_min_x),          // input wire [28 : 0] A
        .B(inv_ray_dir.x),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t0x)     // output wire [48 : 0] P
    );

    mult_gen_0 mult_i_1 (
        .CLK(clk),              // input wire CLK
        .A(sub_max_x),          // input wire [28 : 0] A
        .B(inv_ray_dir.x),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t1x)     // output wire [48 : 0] P
    );

    // y axis
    mult_gen_0 mult_i_2 (
        .CLK(clk),              // input wire CLK
        .A(sub_min_y),          // input wire [28 : 0] A
        .B(inv_ray_dir.y),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t0y)     // output wire [48 : 0] P
    );

    mult_gen_0 mult_i_3 (
        .CLK(clk),              // input wire CLK
        .A(sub_max_y),          // input wire [28 : 0] A
        .B(inv_ray_dir.y),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t1y)     // output wire [48 : 0] P
    );

    // z axis
    mult_gen_0 mult_i_4 (
        .CLK(clk),              // input wire CLK
        .A(sub_min_z),          // input wire [28 : 0] A
        .B(inv_ray_dir.z),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t0z)     // output wire [48 : 0] P
    );

    mult_gen_0 mult_i_5 (
        .CLK(clk),              // input wire CLK
        .A(sub_max_z),          // input wire [28 : 0] A
        .B(inv_ray_dir.z),      // input wire [35 : 0] B
        .CE(~stall),            // input wire CE
        .P(mult_result_t1z)     // output wire [48 : 0] P
    );

    // set mult result to +infinity if there is division by 0
    wire signed [48:0] t0x = div_by_zero_buf[0] ? `NEGATIVE_INFINITY_49 : mult_result_t0x;
    wire signed [48:0] t1x = div_by_zero_buf[0] ? `INFINITY_49 : mult_result_t1x;
    wire signed [48:0] t0y = div_by_zero_buf[1] ? `NEGATIVE_INFINITY_49 : mult_result_t0y;
    wire signed [48:0] t1y = div_by_zero_buf[1] ? `INFINITY_49 : mult_result_t1y;
    wire signed [48:0] t0z = div_by_zero_buf[2] ? `NEGATIVE_INFINITY_49 : mult_result_t0z;
    wire signed [48:0] t1z = div_by_zero_buf[2] ? `INFINITY_49 : mult_result_t1z;

    wire [2:0] swap;
    assign swap[0] = div_by_zero_buf[0] ? 1'b0 : (inv_ray_dir.x < 0); // x
    assign swap[1] = div_by_zero_buf[1] ? 1'b0 : (inv_ray_dir.y < 0); // y
    assign swap[2] = div_by_zero_buf[2] ? 1'b0 : (inv_ray_dir.z < 0); // z

    wire signed [48:0] tmin_x = swap ? t1x : t0x;
    wire signed [48:0] tmax_x = swap ? t0x : t1x;

    wire signed [48:0] tmin_y = swap ? t1y : t0y;
    wire signed [48:0] tmax_y = swap ? t0y : t1y;

    wire signed [48:0] tmin_z = swap ? t1z : t0z;
    wire signed [48:0] tmax_z = swap ? t0z : t1z;

    // // flops to break up combinational logic
    // reg signed [48:0] t0_x_reg, t1_x_reg, t0_y_reg, t1_y_reg, t0_z_reg, t1_z_reg; 

    // `FF_EN(clk, 1'b1, '0, ~stall, t0_x_reg, t0_x)
    // `FF_EN(clk, 1'b1, '0, ~stall, t1_x_reg, t1_x)
    // `FF_EN(clk, 1'b1, '0, ~stall, t0_y_reg, t0_y)
    // `FF_EN(clk, 1'b1, '0, ~stall, t1_y_reg, t1_y)
    // `FF_EN(clk, 1'b1, '0, ~stall, t0_z_reg, t0_z)
    // `FF_EN(clk, 1'b1, '0, ~stall, t1_z_reg, t1_z)

    // wire signed [48:0] tmin_x = (t0_x_reg > prev_range.min) ? t0_x_reg : prev_range.min;
    // wire signed [48:0] tmax_x = (t1_x_reg < prev_range.max) ? t1_x_reg : prev_range.max;

    // wire signed [48:0] tmin_y = (t0_y_reg > prev_range.min) ? t0_y_reg : prev_range.min;
    // wire signed [48:0] tmax_y = (t1_y_reg < prev_range.max) ? t1_y_reg : prev_range.max;

    // wire signed [48:0] tmin_z = (t0_z_reg > prev_range.min) ? t0_z_reg : prev_range.min;
    // wire signed [48:0] tmax_z = (t1_z_reg < prev_range.max) ? t1_z_reg : prev_range.max;
    
    // outputs
    assign hit = ~((tmax_x <= tmin_x) | (tmax_y <= tmin_y) | (tmax_z <= tmin_z)); 

    // assign range_out.min = (tmin_x > tmin_y) ? ((tmin_x > tmin_z) ? tmin_x : tmin_z) : ((tmin_y > tmin_z) ? tmin_y : tmin_z);
    // assign range_out.max = (tmax_x < tmax_y) ? ((tmax_x < tmax_z) ? tmax_x : tmax_z) : ((tmax_y < tmax_z) ? tmax_y : tmax_z);

    assign closest_hit_distance = (tmin_x > tmin_y) ? ((tmin_x > tmin_z) ? tmin_x : tmin_z) : ((tmin_y > tmin_z) ? tmin_y : tmin_z);
        
endmodule
