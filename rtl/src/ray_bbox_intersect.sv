`timescale 1ns/1ps

`include "ff_macros.svh"

/*
This module determines if a ray intersects with a bbox, and computes the hit distance from the ray origin if so,
using the formula t = (plane - origin) x 1/d for each face of the axis aligned bbox, 2 per axis. In the upstream module we represented 1/d using
1/d = (-1)^sign * mantissa * 2^shift

The negation term can be implemented by reversing the subtraction terms if the sign bit is set

ds_bbox_distance_o is the box entry time: negative when the origin is inside the box, don't-care on a miss.

THE LATENCY OF THIS MODULE IS 4 CYCLES
*/
module ray_bbox_intersect 
    import data_structs_pkg::*;
(
    input wire clk,
    input wire rst,

    // upstream interface
    // data
    input  point_t     us_ray_orig_i,

    input wire [16:0]  us_inv_dir_mantissa_x_i,   // Q1.16
    input wire [16:0]  us_inv_dir_mantissa_y_i,   // Q1.16
    input wire [16:0]  us_inv_dir_mantissa_z_i,   // Q1.16

    input wire         us_inv_dir_sign_x_i,
    input wire         us_inv_dir_sign_y_i,
    input wire         us_inv_dir_sign_z_i,

    input wire         us_inv_dir_div_by_zero_x_i,
    input wire         us_inv_dir_div_by_zero_y_i,
    input wire         us_inv_dir_div_by_zero_z_i,

    input wire [4:0]   us_inv_dir_shift_x_i,
    input wire [4:0]   us_inv_dir_shift_y_i,
    input wire [4:0]   us_inv_dir_shift_z_i,

    input bbox_t       us_box_i,
    // control
    input  wire        us_vld_i,
    output wire        us_stall_o,

    // downstream interface
    // data
    output wire                ds_hit_o,
    output wire signed [29:0]  ds_bbox_distance_o,  // SQ13.16
    // control
    output wire         ds_vld_o,
    input  wire         ds_stall_i

);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 1 OF 4
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    logic signed [29:0] sub_near_x_pre_round;  // SQ13.16
    logic signed [29:0] sub_far_x_pre_round;   // SQ13.16  
    logic signed [29:0] sub_near_y_pre_round;  // SQ13.16
    logic signed [29:0] sub_far_y_pre_round;   // SQ13.16
    logic signed [29:0] sub_near_z_pre_round;  // SQ13.16
    logic signed [29:0] sub_far_z_pre_round;   // SQ13.16       

    // 25 total bits to fit into DSP port
    logic signed [24:0] sub_near_x_d, sub_near_x_q; // SQ13.11
    logic signed [24:0] sub_far_x_d,  sub_far_x_q;  // SQ13.11
    logic signed [24:0] sub_near_y_d, sub_near_y_q; // SQ13.11
    logic signed [24:0] sub_far_y_d,  sub_far_y_q;  // SQ13.11
    logic signed [24:0] sub_near_z_d, sub_near_z_q; // SQ13.11
    logic signed [24:0] sub_far_z_d,  sub_far_z_q;  // SQ13.11 

    logic signed [27:0] op_a_x_near, op_b_x_near;   // SQ11.16 
    logic signed [27:0] op_a_y_near, op_b_y_near;   // SQ11.16 
    logic signed [27:0] op_a_z_near, op_b_z_near;   // SQ11.16 
    logic signed [27:0] op_a_x_far, op_b_x_far;   // SQ11.16 
    logic signed [27:0] op_a_y_far, op_b_y_far;   // SQ11.16 
    logic signed [27:0] op_a_z_far, op_b_z_far;   // SQ11.16 

    logic [16:0] inv_dir_mantissa_x_q;      // Q1.16
    logic [16:0] inv_dir_mantissa_y_q;      // Q1.16
    logic [16:0] inv_dir_mantissa_z_q;      // Q1.16

    logic [4:0] inv_dir_shift_x_q1;
    logic [4:0] inv_dir_shift_y_q1;
    logic [4:0] inv_dir_shift_z_q1;

    logic [2:0]  ray_orig_inside_bbox_d;
    logic [2:0]  ray_orig_inside_bbox_q1;

    logic [2:0]  div_by_zero_d;
    logic [2:0]  div_by_zero_q1;

    logic        vld_q1;

    // concatenate div by 0 information into one signal, x in the LSB and z in the MSB
    assign div_by_zero_d = {us_inv_dir_div_by_zero_z_i, us_inv_dir_div_by_zero_y_i, us_inv_dir_div_by_zero_x_i};

    // signals for bounds checking in case ray origin is inside the bbox
    assign ray_orig_inside_bbox_d[0] = (us_ray_orig_i.x >= us_box_i.min.x) & (us_ray_orig_i.x <= us_box_i.max.x);
    assign ray_orig_inside_bbox_d[1] = (us_ray_orig_i.y >= us_box_i.min.y) & (us_ray_orig_i.y <= us_box_i.max.y);
    assign ray_orig_inside_bbox_d[2] = (us_ray_orig_i.z >= us_box_i.min.z) & (us_ray_orig_i.z <= us_box_i.max.z);

    // the sign bit determines two things
    //      1. order of subtraction terms -> t = (plane - origin) * mantissa * 2^shift * (-1) = (origin - plane) * mantissa * 2^shift
    //      2. Which is the nearest plane hit and which is the farthest
    //         to understand this, picture a ray with origin (0, 0, 0) direction (-1, 0, 0), and a bounding box in the -x direction
    //         the closer x plane hit is the greater number value, which is opposite from if everything was on the positive side
    //
    // we want to apply both of these muxes to the operands to reduce the amount of subtractors needed in the hardware, and to fold the muxes
    // into the LUTs, which can't be done if we mux after the subtract
    assign op_a_x_near = us_inv_dir_sign_x_i ? us_ray_orig_i.x : us_box_i.min.x;
    assign op_b_x_near = us_inv_dir_sign_x_i ? us_box_i.max.x  : us_ray_orig_i.x;

    assign op_a_x_far = us_inv_dir_sign_x_i ? us_ray_orig_i.x : us_box_i.max.x;
    assign op_b_x_far = us_inv_dir_sign_x_i ? us_box_i.min.x  : us_ray_orig_i.x;

    assign op_a_y_near = us_inv_dir_sign_y_i ? us_ray_orig_i.y : us_box_i.min.y;
    assign op_b_y_near = us_inv_dir_sign_y_i ? us_box_i.max.y  : us_ray_orig_i.y;

    assign op_a_y_far = us_inv_dir_sign_y_i ? us_ray_orig_i.y : us_box_i.max.y;
    assign op_b_y_far = us_inv_dir_sign_y_i ? us_box_i.min.y  : us_ray_orig_i.y;

    assign op_a_z_near = us_inv_dir_sign_z_i ? us_ray_orig_i.z : us_box_i.min.z;
    assign op_b_z_near = us_inv_dir_sign_z_i ? us_box_i.max.z  : us_ray_orig_i.z;

    assign op_a_z_far = us_inv_dir_sign_z_i ? us_ray_orig_i.z : us_box_i.max.z;
    assign op_b_z_far = us_inv_dir_sign_z_i ? us_box_i.min.z  : us_ray_orig_i.z;

    assign sub_near_x_pre_round = op_a_x_near - op_b_x_near;
    assign sub_far_x_pre_round  = op_a_x_far - op_b_x_far + 6'sh1f;   // add 6'sh1f so that a 5 bit truncate in the next step rounds up

    assign sub_near_y_pre_round = op_a_y_near - op_b_y_near;
    assign sub_far_y_pre_round  = op_a_y_far - op_b_y_far + 6'sh1f;   // add 6'sh1f so that a 5 bit truncate in the next step rounds up

    assign sub_near_z_pre_round = op_a_z_near - op_b_z_near;
    assign sub_far_z_pre_round  = op_a_z_far - op_b_z_far + 6'sh1f;   // add 6'sh1f so that a 5 bit truncate in the next step rounds up

    // we then round this value conservatively (bounding boxes will be slightly bigger than they need to be for their contained primitives,
    // near values round down, far values round up) so that we may use less fractional bits, and our multiply can fit into a single DSP, which
    // saves precious board resources
    assign sub_near_x_d = sub_near_x_pre_round[29:5];
    assign sub_far_x_d  = sub_far_x_pre_round[29:5];
    assign sub_near_y_d = sub_near_y_pre_round[29:5];
    assign sub_far_y_d  = sub_far_y_pre_round[29:5];
    assign sub_near_z_d = sub_near_z_pre_round[29:5];
    assign sub_far_z_d  = sub_far_z_pre_round[29:5];

    `FFLNR(sub_near_x_q, sub_near_x_d, ~ds_stall_i, clk)
    `FFLNR(sub_far_x_q, sub_far_x_d, ~ds_stall_i, clk)
    `FFLNR(sub_near_y_q, sub_near_y_d, ~ds_stall_i, clk)
    `FFLNR(sub_far_y_q, sub_far_y_d, ~ds_stall_i, clk)
    `FFLNR(sub_near_z_q, sub_near_z_d, ~ds_stall_i, clk)
    `FFLNR(sub_far_z_q, sub_far_z_d, ~ds_stall_i, clk)

    `FFLNR(inv_dir_mantissa_x_q, us_inv_dir_mantissa_x_i, ~ds_stall_i, clk)
    `FFLNR(inv_dir_mantissa_y_q, us_inv_dir_mantissa_y_i, ~ds_stall_i, clk)
    `FFLNR(inv_dir_mantissa_z_q, us_inv_dir_mantissa_z_i, ~ds_stall_i, clk)

    `FFLNR(inv_dir_shift_x_q1, us_inv_dir_shift_x_i, ~ds_stall_i, clk)
    `FFLNR(inv_dir_shift_y_q1, us_inv_dir_shift_y_i, ~ds_stall_i, clk)
    `FFLNR(inv_dir_shift_z_q1, us_inv_dir_shift_z_i, ~ds_stall_i, clk)

    `FFLNR(ray_orig_inside_bbox_q1, ray_orig_inside_bbox_d, ~ds_stall_i, clk)
    `FFLNR(div_by_zero_q1, div_by_zero_d, ~ds_stall_i, clk)

    `FFLSR(vld_q1, us_vld_i, ~ds_stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 2 OF 4
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 

    logic signed [42:0] mult_result_x_near_d, mult_result_x_near_q; // SQ15.27
    logic signed [42:0] mult_result_x_far_d, mult_result_x_far_q;   // SQ15.27
    logic signed [42:0] mult_result_y_near_d, mult_result_y_near_q; // SQ15.27
    logic signed [42:0] mult_result_y_far_d, mult_result_y_far_q;   // SQ15.27
    logic signed [42:0] mult_result_z_near_d, mult_result_z_near_q; // SQ15.27
    logic signed [42:0] mult_result_z_far_d, mult_result_z_far_q;   // SQ15.27

    logic [4:0] inv_dir_shift_x_q2;
    logic [4:0] inv_dir_shift_y_q2;
    logic [4:0] inv_dir_shift_z_q2;

    logic [2:0]  ray_orig_inside_bbox_q2;
    logic [2:0]  div_by_zero_q2;

    logic        vld_q2;

    // t = (subtraction_term) * mantissa * 2^shift for each axis
    // make both operands signed and multiply the mantissa by the subtraction term
    assign mult_result_x_near_d = $signed({1'b0, inv_dir_mantissa_x_q}) * sub_near_x_q; // SQ1.16 * SQ13.11 = SQ15.27
    assign mult_result_x_far_d  = $signed({1'b0, inv_dir_mantissa_x_q}) * sub_far_x_q;  // SQ1.16 * SQ13.11 = SQ15.27
    assign mult_result_y_near_d = $signed({1'b0, inv_dir_mantissa_y_q}) * sub_near_y_q; // SQ1.16 * SQ13.11 = SQ15.27
    assign mult_result_y_far_d  = $signed({1'b0, inv_dir_mantissa_y_q}) * sub_far_y_q;  // SQ1.16 * SQ13.11 = SQ15.27
    assign mult_result_z_near_d = $signed({1'b0, inv_dir_mantissa_z_q}) * sub_near_z_q; // SQ1.16 * SQ13.11 = SQ15.27
    assign mult_result_z_far_d  = $signed({1'b0, inv_dir_mantissa_z_q}) * sub_far_z_q;  // SQ1.16 * SQ13.11 = SQ15.27

    `FFLNR(mult_result_x_near_q, mult_result_x_near_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_x_far_q, mult_result_x_far_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_y_near_q, mult_result_y_near_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_y_far_q, mult_result_y_far_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_z_near_q, mult_result_z_near_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_z_far_q, mult_result_z_far_d, ~ds_stall_i, clk)

    `FFLNR(inv_dir_shift_x_q2, inv_dir_shift_x_q1, ~ds_stall_i, clk)
    `FFLNR(inv_dir_shift_y_q2, inv_dir_shift_y_q1, ~ds_stall_i, clk)
    `FFLNR(inv_dir_shift_z_q2, inv_dir_shift_z_q1, ~ds_stall_i, clk)

    `FFLNR(div_by_zero_q2, div_by_zero_q1, ~ds_stall_i, clk)
    `FFLNR(ray_orig_inside_bbox_q2, ray_orig_inside_bbox_q1, ~ds_stall_i, clk)

    `FFLSR(vld_q2, vld_q1, ~ds_stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 3 OF 4
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 

    // must be able to store a shift of SQ15.27 being shifted up to 16 places left without losing information
    logic signed [58:0] mult_result_x_near_shifted; // SQ31.27
    logic signed [58:0] mult_result_x_far_shifted;  // SQ31.27
    logic signed [58:0] mult_result_y_near_shifted; // SQ31.27
    logic signed [58:0] mult_result_y_far_shifted;  // SQ31.27
    logic signed [58:0] mult_result_z_near_shifted; // SQ31.27
    logic signed [58:0] mult_result_z_far_shifted;  // SQ31.27

    // the maximum hit distance for our chosen supported world space of +/-2048 on all axes is ~7095, which fits in 13 integer bits,
    // anything larger may be set to our "infinity" constant. Also trim our fractional precision down to 16 bits
    logic signed [29:0] mult_result_x_near_saturated_d, mult_result_x_near_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_x_far_saturated_d, mult_result_x_far_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_y_near_saturated_d, mult_result_y_near_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_y_far_saturated_d, mult_result_y_far_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_z_near_saturated_d, mult_result_z_near_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_z_far_saturated_d, mult_result_z_far_saturated_q; // SQ13.16

    logic x_near_pos_saturated, x_near_neg_saturated;
    logic x_far_pos_saturated, x_far_neg_saturated;
    logic y_near_pos_saturated, y_near_neg_saturated;
    logic y_far_pos_saturated, y_far_neg_saturated;
    logic z_near_pos_saturated, z_near_neg_saturated;
    logic z_far_pos_saturated, z_far_neg_saturated;

    logic [2:0]  ray_orig_inside_bbox_q3;
    logic [2:0]  div_by_zero_q3;

    logic        vld_q3;

    // t = (subtraction_term) * mantissa * 2^shift for each axis
    // apply the shift term
    assign mult_result_x_near_shifted = mult_result_x_near_q << inv_dir_shift_x_q2;
    assign mult_result_x_far_shifted = mult_result_x_far_q << inv_dir_shift_x_q2;
    assign mult_result_y_near_shifted = mult_result_y_near_q << inv_dir_shift_y_q2;
    assign mult_result_y_far_shifted = mult_result_y_far_q << inv_dir_shift_y_q2;
    assign mult_result_z_near_shifted = mult_result_z_near_q << inv_dir_shift_z_q2;
    assign mult_result_z_far_shifted = mult_result_z_far_q << inv_dir_shift_z_q2;

    // these are the conditions that determine saturation for each of the trimmed values
    // we check the bit range [58:40] because these would be sign extension bits for numbers that fit in our desired SQ13.16 format 
    assign x_near_pos_saturated = !mult_result_x_near_shifted[58] && (|mult_result_x_near_shifted[57:40]);
    assign x_near_neg_saturated =  mult_result_x_near_shifted[58] && (~&mult_result_x_near_shifted[57:40]);

    assign x_far_pos_saturated = !mult_result_x_far_shifted[58] && (|mult_result_x_far_shifted[57:40]);
    assign x_far_neg_saturated =  mult_result_x_far_shifted[58] && (~&mult_result_x_far_shifted[57:40]);

    assign y_near_pos_saturated = !mult_result_y_near_shifted[58] && (|mult_result_y_near_shifted[57:40]);
    assign y_near_neg_saturated =  mult_result_y_near_shifted[58] && (~&mult_result_y_near_shifted[57:40]);

    assign y_far_pos_saturated = !mult_result_y_far_shifted[58] && (|mult_result_y_far_shifted[57:40]);
    assign y_far_neg_saturated =  mult_result_y_far_shifted[58] && (~&mult_result_y_far_shifted[57:40]);

    assign z_near_pos_saturated = !mult_result_z_near_shifted[58] && (|mult_result_z_near_shifted[57:40]);
    assign z_near_neg_saturated =  mult_result_z_near_shifted[58] && (~&mult_result_z_near_shifted[57:40]);

    assign z_far_pos_saturated = !mult_result_z_far_shifted[58] && (|mult_result_z_far_shifted[57:40]);
    assign z_far_neg_saturated =  mult_result_z_far_shifted[58] && (~&mult_result_z_far_shifted[57:40]);

    // saturate based on our established conditions
    assign mult_result_x_near_saturated_d = x_near_pos_saturated ? INFINITY_SQ13_16 : (x_near_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_x_near_shifted[40:11]);
    assign mult_result_x_far_saturated_d = x_far_pos_saturated ? INFINITY_SQ13_16 : (x_far_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_x_far_shifted[40:11]); 

    assign mult_result_y_near_saturated_d = y_near_pos_saturated ? INFINITY_SQ13_16 : (y_near_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_y_near_shifted[40:11]);
    assign mult_result_y_far_saturated_d = y_far_pos_saturated ? INFINITY_SQ13_16 : (y_far_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_y_far_shifted[40:11]); 

    assign mult_result_z_near_saturated_d = z_near_pos_saturated ? INFINITY_SQ13_16 : (z_near_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_z_near_shifted[40:11]);
    assign mult_result_z_far_saturated_d = z_far_pos_saturated ? INFINITY_SQ13_16 : (z_far_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_z_far_shifted[40:11]); 

    `FFLNR(mult_result_x_near_saturated_q, mult_result_x_near_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_x_far_saturated_q, mult_result_x_far_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_y_near_saturated_q, mult_result_y_near_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_y_far_saturated_q, mult_result_y_far_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_z_near_saturated_q, mult_result_z_near_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_z_far_saturated_q, mult_result_z_far_saturated_d, ~ds_stall_i, clk)

    `FFLNR(div_by_zero_q3, div_by_zero_q2, ~ds_stall_i, clk)
    `FFLNR(ray_orig_inside_bbox_q3, ray_orig_inside_bbox_q2, ~ds_stall_i, clk)

    `FFLSR(vld_q3, vld_q2, ~ds_stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 4 OF 4
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    logic signed [29:0] t_x_near; // SQ13.16
    logic signed [29:0] t_x_far; // SQ13.16
    logic signed [29:0] t_y_near; // SQ13.16
    logic signed [29:0] t_y_far; // SQ13.16
    logic signed [29:0] t_z_near; // SQ13.16
    logic signed [29:0] t_z_far; // SQ13.16

    logic near_far_spans_overlap;
    logic box_behind_ray;

    logic               hit_d, hit_q;

    logic signed [29:0] time_lower_bound_d, time_lower_bound_q; // SQ13.16


    logic              vld_q4;

    // set hit distance to +/-infinity if there is division by 0
    assign t_x_near = div_by_zero_q3[0] ? NEGATIVE_INFINITY_SQ13_16 : mult_result_x_near_saturated_q;
    assign t_x_far = div_by_zero_q3[0] ? INFINITY_SQ13_16 : mult_result_x_far_saturated_q;
    assign t_y_near = div_by_zero_q3[1] ? NEGATIVE_INFINITY_SQ13_16 : mult_result_y_near_saturated_q;
    assign t_y_far = div_by_zero_q3[1] ? INFINITY_SQ13_16 : mult_result_y_far_saturated_q;
    assign t_z_near = div_by_zero_q3[2] ? NEGATIVE_INFINITY_SQ13_16 : mult_result_z_near_saturated_q;
    assign t_z_far = div_by_zero_q3[2] ? INFINITY_SQ13_16 : mult_result_z_far_saturated_q;

    // the ray misses if the span of near times overlaps the span of far times, which happens when any near time is greater than any far time.
    // This can be done without chaining comparisons by comparing each near time against every far time (9 parallel comparisons). However, we
    // already know that the near hit on one axis is less than or equal to the far hit on that same axis, so this condition can be checked with
    // 6 total comparisons OR'd together
    assign near_far_spans_overlap = (t_x_near > t_y_far) | (t_x_near > t_z_far) | (t_y_near > t_x_far) | (t_y_near > t_z_far) |
                                    (t_z_near > t_x_far) | (t_z_near > t_y_far); 

    // A negative far time means the ray left that axis's range before t = 0, so the box is behind the ray.
    assign box_behind_ray = t_x_far[29] | t_y_far[29] | t_z_far[29];

    // check all the conditions that indicate a miss and invert 
    assign hit_d = ~(near_far_spans_overlap | box_behind_ray |
                    (div_by_zero_q3[0] & !ray_orig_inside_bbox_q3[0]) |
                    (div_by_zero_q3[1] & !ray_orig_inside_bbox_q3[1]) |
                    (div_by_zero_q3[2] & !ray_orig_inside_bbox_q3[2]));

    assign time_lower_bound_d = (t_x_near > t_y_near) ? ((t_x_near > t_z_near) ? t_x_near : t_z_near) : ((t_y_near > t_z_near) ? t_y_near : t_z_near);

    `FFLNR(hit_q, hit_d, ~ds_stall_i, clk)
    `FFLNR(time_lower_bound_q, time_lower_bound_d, ~ds_stall_i, clk)

    `FFLSR(vld_q4, vld_q3, ~ds_stall_i, '0, clk, rst)
    
    
    assign ds_hit_o = hit_q;
    assign ds_bbox_distance_o = time_lower_bound_q;

    assign ds_vld_o = vld_q4;
    assign us_stall_o = ds_stall_i;
        
endmodule
