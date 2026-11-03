`timescale 1ns/1ps

`include "ff_macros.svh"

/*
This module determines if a ray intersects with a bbox, and computing the hit distance from the ray origin if so,
using the formula t = (plane - origin) x 1/d for each face of the axis aligned bbox, 2 per axis. In the upstream module we represented 1/d using
1/d = (-1)^sign * mantissa * 2^shift

The negation term can be implemented by reversing the subtraction terms if the sign bit is set

THE LATENCY OF THIS MODULE IS 5 CYCLES
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
    input range_t      us_last_times_i,
    // control
    input  wire        us_vld_i,
    output wire        us_stall_o,

    // downstream interface
    // data
    output wire        ds_hit_o,
    output range_t     ds_times_o,
    // control
    output wire ds_vld_o,
    input  wire ds_stall_i

);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 1 OF 5
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    logic signed [28:0] sub_min_x_d, sub_min_x_q;  // SQ12.16
    logic signed [28:0] sub_max_x_d, sub_max_x_q;  // SQ12.16
    logic signed [28:0] sub_min_y_d, sub_min_y_q;  // SQ12.16
    logic signed [28:0] sub_max_y_d, sub_max_y_q;  // SQ12.16
    logic signed [28:0] sub_min_z_d, sub_min_z_q;  // SQ12.16
    logic signed [28:0] sub_max_z_d, sub_max_z_q;  // SQ12.16

    logic [16:0] inv_dir_mantissa_x_q;      // Q1.16
    logic [16:0] inv_dir_mantissa_y_q;      // Q1.16
    logic [16:0] inv_dir_mantissa_z_q;      // Q1.16

    logic [4:0] inv_dir_shift_x_q1;
    logic [4:0] inv_dir_shift_y_q1;
    logic [4:0] inv_dir_shift_z_q1;

    logic [2:0]  swap_min_max_d;
    logic [2:0]  swap_min_max_q1;

    logic [2:0]  ray_orig_inside_bbox_d;
    logic [2:0]  ray_orig_inside_bbox_q1;

    logic [2:0]  div_by_zero_d;
    logic [2:0]  div_by_zero_q1;

    range_t      last_times_q1;

    logic        vld_q1;

    // concatenate div by 0 information into one signal, x in the LSB and z in the MSB
    assign div_by_zero_d = {us_inv_dir_div_by_zero_z_i, us_inv_dir_div_by_zero_y_i, us_inv_dir_div_by_zero_x_i};

    // signals for bounds checking in case ray origin is inside the bbox
    assign ray_orig_inside_bbox_d[0] = (us_ray_orig_i.x >= us_box_i.min.x) & (us_ray_orig_i.x <= us_box_i.max.x);
    assign ray_orig_inside_bbox_d[1] = (us_ray_orig_i.y >= us_box_i.min.y) & (us_ray_orig_i.y <= us_box_i.max.y);
    assign ray_orig_inside_bbox_d[2] = (us_ray_orig_i.z >= us_box_i.min.z) & (us_ray_orig_i.z <= us_box_i.max.z);

    // swap min and max signal based on the ray direction (in the div by 0 case, don't swap)
    assign swap_min_max_d[0] = us_inv_dir_div_by_zero_x_i ? 1'b0 : us_inv_dir_sign_x_i;
    assign swap_min_max_d[1] = us_inv_dir_div_by_zero_y_i ? 1'b0 : us_inv_dir_sign_y_i;
    assign swap_min_max_d[2] = us_inv_dir_div_by_zero_z_i ? 1'b0 : us_inv_dir_sign_z_i;

    // swap the subtraction terms around if the sign bit is set
    // t = (plane - origin) * mantissa * 2^shift * (-1)^sign for each axis
    // t = (plane - origin) * mantissa * 2^shift * (-1) == (origin - plane) * mantissa * 2^shift
    assign sub_min_x_d = us_inv_dir_sign_x_i ? (us_ray_orig_i.x - us_box_i.min.x) : (us_box_i.min.x - us_ray_orig_i.x);
    assign sub_max_x_d = us_inv_dir_sign_x_i ? (us_ray_orig_i.x - us_box_i.max.x) : (us_box_i.max.x - us_ray_orig_i.x);
    assign sub_min_y_d = us_inv_dir_sign_y_i ? (us_ray_orig_i.y - us_box_i.min.y) : (us_box_i.min.y - us_ray_orig_i.y);
    assign sub_max_y_d = us_inv_dir_sign_y_i ? (us_ray_orig_i.y - us_box_i.max.y) : (us_box_i.max.y - us_ray_orig_i.y);
    assign sub_min_z_d = us_inv_dir_sign_z_i ? (us_ray_orig_i.z - us_box_i.min.z) : (us_box_i.min.z - us_ray_orig_i.z);
    assign sub_max_z_d = us_inv_dir_sign_z_i ? (us_ray_orig_i.z - us_box_i.max.z) : (us_box_i.max.z - us_ray_orig_i.z);

    // ideally this register gets absorbed into the mult DSPs, along with the subtraction operation
    `FFLNR(sub_min_x_q, sub_min_x_d, ~ds_stall_i, clk)
    `FFLNR(sub_max_x_q, sub_max_x_d, ~ds_stall_i, clk)
    `FFLNR(sub_min_y_q, sub_min_y_d, ~ds_stall_i, clk)
    `FFLNR(sub_max_y_q, sub_max_y_d, ~ds_stall_i, clk)
    `FFLNR(sub_min_z_q, sub_min_z_d, ~ds_stall_i, clk)
    `FFLNR(sub_max_z_q, sub_max_z_d, ~ds_stall_i, clk)

    `FFLNR(inv_dir_mantissa_x_q, us_inv_dir_mantissa_x_i, ~ds_stall_i, clk)
    `FFLNR(inv_dir_mantissa_y_q, us_inv_dir_mantissa_y_i, ~ds_stall_i, clk)
    `FFLNR(inv_dir_mantissa_z_q, us_inv_dir_mantissa_z_i, ~ds_stall_i, clk)

    `FFLNR(inv_dir_shift_x_q1, us_inv_dir_shift_x_i, ~ds_stall_i, clk)
    `FFLNR(inv_dir_shift_y_q1, us_inv_dir_shift_y_i, ~ds_stall_i, clk)
    `FFLNR(inv_dir_shift_z_q1, us_inv_dir_shift_z_i, ~ds_stall_i, clk)

    `FFLNR(swap_min_max_q1, swap_min_max_d, ~ds_stall_i, clk)
    `FFLNR(ray_orig_inside_bbox_q1, ray_orig_inside_bbox_d, ~ds_stall_i, clk)
    `FFLNR(div_by_zero_q1, div_by_zero_d, ~ds_stall_i, clk)

    `FFLNR(last_times_q1, us_last_times_i, ~ds_stall_i, clk)

    `FFLSR(vld_q1, us_vld_i, ~ds_stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 2 OF 5
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 

    logic signed [46:0] mult_result_x_t0_d, mult_result_x_t0_q; // SQ14.32
    logic signed [46:0] mult_result_x_t1_d, mult_result_x_t1_q; // SQ14.32
    logic signed [46:0] mult_result_y_t0_d, mult_result_y_t0_q; // SQ14.32
    logic signed [46:0] mult_result_y_t1_d, mult_result_y_t1_q; // SQ14.32
    logic signed [46:0] mult_result_z_t0_d, mult_result_z_t0_q; // SQ14.32
    logic signed [46:0] mult_result_z_t1_d, mult_result_z_t1_q; // SQ14.32

    logic [4:0] inv_dir_shift_x_q2;
    logic [4:0] inv_dir_shift_y_q2;
    logic [4:0] inv_dir_shift_z_q2;

    logic [2:0]  swap_min_max_q2;
    logic [2:0]  ray_orig_inside_bbox_q2;
    logic [2:0]  div_by_zero_q2;

    range_t      last_times_q2;

    logic        vld_q2;

    // t = (subtraction_term) * mantissa * 2^shift for each axis
    // make both operands signed and multiply the mantissa by the subtraction term
    assign mult_result_x_t0_d = $signed({1'b0, inv_dir_mantissa_x_q}) * sub_min_x_q; // SQ1.16 * SQ12.16 = SQ14.32
    assign mult_result_x_t1_d = $signed({1'b0, inv_dir_mantissa_x_q}) * sub_max_x_q; // SQ1.16 * SQ12.16 = SQ14.32
    assign mult_result_y_t0_d = $signed({1'b0, inv_dir_mantissa_y_q}) * sub_min_y_q; // SQ1.16 * SQ12.16 = SQ14.32
    assign mult_result_y_t1_d = $signed({1'b0, inv_dir_mantissa_y_q}) * sub_max_y_q; // SQ1.16 * SQ12.16 = SQ14.32
    assign mult_result_z_t0_d = $signed({1'b0, inv_dir_mantissa_z_q}) * sub_min_z_q; // SQ1.16 * SQ12.16 = SQ14.32
    assign mult_result_z_t1_d = $signed({1'b0, inv_dir_mantissa_z_q}) * sub_max_z_q; // SQ1.16 * SQ12.16 = SQ14.32

    `FFLNR(mult_result_x_t0_q, mult_result_x_t0_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_x_t1_q, mult_result_x_t1_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_y_t0_q, mult_result_y_t0_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_y_t1_q, mult_result_y_t1_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_z_t0_q, mult_result_z_t0_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_z_t1_q, mult_result_z_t1_d, ~ds_stall_i, clk)

    `FFLNR(inv_dir_shift_x_q2, inv_dir_shift_x_q1, ~ds_stall_i, clk)
    `FFLNR(inv_dir_shift_y_q2, inv_dir_shift_y_q1, ~ds_stall_i, clk)
    `FFLNR(inv_dir_shift_z_q2, inv_dir_shift_z_q1, ~ds_stall_i, clk)

    `FFLNR(swap_min_max_q2, swap_min_max_q1, ~ds_stall_i, clk)
    `FFLNR(div_by_zero_q2, div_by_zero_q1, ~ds_stall_i, clk)
    `FFLNR(ray_orig_inside_bbox_q2, ray_orig_inside_bbox_q1, ~ds_stall_i, clk)

    `FFLNR(last_times_q2, last_times_q1, ~ds_stall_i, clk)

    `FFLSR(vld_q2, vld_q1, ~ds_stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 3 OF 5
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 

    // must be able to store a shift of SQ14.32 being shifted up to 16 places left without losing information
    logic signed [62:0] mult_result_x_t0_shifted; // SQ30.32
    logic signed [62:0] mult_result_x_t1_shifted; // SQ30.32
    logic signed [62:0] mult_result_y_t0_shifted; // SQ30.32
    logic signed [62:0] mult_result_y_t1_shifted; // SQ30.32
    logic signed [62:0] mult_result_z_t0_shifted; // SQ30.32
    logic signed [62:0] mult_result_z_t1_shifted; // SQ30.32

    // the maximum hit distance for our chosen supported world space of +=2048 on all axes is ~7095, which fits in 13 integer bits,
    // anything larger may be set to our "infinity" constant. Also trim our fractional precision down to 16 bits
    logic signed [29:0] mult_result_x_t0_saturated_d, mult_result_x_t0_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_x_t1_saturated_d, mult_result_x_t1_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_y_t0_saturated_d, mult_result_y_t0_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_y_t1_saturated_d, mult_result_y_t1_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_z_t0_saturated_d, mult_result_z_t0_saturated_q; // SQ13.16
    logic signed [29:0] mult_result_z_t1_saturated_d, mult_result_z_t1_saturated_q; // SQ13.16

    logic x_t0_pos_saturated, x_t0_neg_saturated;
    logic x_t1_pos_saturated, x_t1_neg_saturated;
    logic y_t0_pos_saturated, y_t0_neg_saturated;
    logic y_t1_pos_saturated, y_t1_neg_saturated;
    logic z_t0_pos_saturated, z_t0_neg_saturated;
    logic z_t1_pos_saturated, z_t1_neg_saturated;

    logic [2:0]  swap_min_max_q3;
    logic [2:0]  ray_orig_inside_bbox_q3;
    logic [2:0]  div_by_zero_q3;

    range_t      last_times_q3;

    logic        vld_q3;

    // t = (subtraction_term) * mantissa * 2^shift for each axis
    // apply the shift term
    assign mult_result_x_t0_shifted = mult_result_x_t0_q << inv_dir_shift_x_q2;
    assign mult_result_x_t1_shifted = mult_result_x_t1_q << inv_dir_shift_x_q2;
    assign mult_result_y_t0_shifted = mult_result_y_t0_q << inv_dir_shift_y_q2;
    assign mult_result_y_t1_shifted = mult_result_y_t1_q << inv_dir_shift_y_q2;
    assign mult_result_z_t0_shifted = mult_result_z_t0_q << inv_dir_shift_z_q2;
    assign mult_result_z_t1_shifted = mult_result_z_t1_q << inv_dir_shift_z_q2;

    // these are the conditions that determine saturation for each of the trimmed values
    // we check the bit range [62:45] because these would be sign extension bits for numbers that fit in our desired SQ13.16 format 
    assign x_t0_pos_saturated = !mult_result_x_t0_shifted[62] && (|mult_result_x_t0_shifted[61:45]);
    assign x_t0_neg_saturated =  mult_result_x_t0_shifted[62] && (~&mult_result_x_t0_shifted[61:45]);

    assign x_t1_pos_saturated = !mult_result_x_t1_shifted[62] && (|mult_result_x_t1_shifted[61:45]);
    assign x_t1_neg_saturated =  mult_result_x_t1_shifted[62] && (~&mult_result_x_t1_shifted[61:45]);

    assign y_t0_pos_saturated = !mult_result_y_t0_shifted[62] && (|mult_result_y_t0_shifted[61:45]);
    assign y_t0_neg_saturated =  mult_result_y_t0_shifted[62] && (~&mult_result_y_t0_shifted[61:45]);

    assign y_t1_pos_saturated = !mult_result_y_t1_shifted[62] && (|mult_result_y_t1_shifted[61:45]);
    assign y_t1_neg_saturated =  mult_result_y_t1_shifted[62] && (~&mult_result_y_t1_shifted[61:45]);

    assign z_t0_pos_saturated = !mult_result_z_t0_shifted[62] && (|mult_result_z_t0_shifted[61:45]);
    assign z_t0_neg_saturated =  mult_result_z_t0_shifted[62] && (~&mult_result_z_t0_shifted[61:45]);

    assign z_t1_pos_saturated = !mult_result_z_t1_shifted[62] && (|mult_result_z_t1_shifted[61:45]);
    assign z_t1_neg_saturated =  mult_result_z_t1_shifted[62] && (~&mult_result_z_t1_shifted[61:45]);

    // saturate based on our established conditions
    assign mult_result_x_t0_saturated_d = x_t0_pos_saturated ? INFINITY_SQ13_16 : (x_t0_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_x_t0_shifted[45:16]);
    assign mult_result_x_t1_saturated_d = x_t1_pos_saturated ? INFINITY_SQ13_16 : (x_t1_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_x_t1_shifted[45:16]); 

    assign mult_result_y_t0_saturated_d = y_t0_pos_saturated ? INFINITY_SQ13_16 : (y_t0_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_y_t0_shifted[45:16]);
    assign mult_result_y_t1_saturated_d = y_t1_pos_saturated ? INFINITY_SQ13_16 : (y_t1_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_y_t1_shifted[45:16]); 

    assign mult_result_z_t0_saturated_d = z_t0_pos_saturated ? INFINITY_SQ13_16 : (z_t0_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_z_t0_shifted[45:16]);
    assign mult_result_z_t1_saturated_d = z_t1_pos_saturated ? INFINITY_SQ13_16 : (z_t1_neg_saturated ? NEGATIVE_INFINITY_SQ13_16 : mult_result_z_t1_shifted[45:16]); 

    `FFLNR(mult_result_x_t0_saturated_q, mult_result_x_t0_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_x_t1_saturated_q, mult_result_x_t1_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_y_t0_saturated_q, mult_result_y_t0_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_y_t1_saturated_q, mult_result_y_t1_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_z_t0_saturated_q, mult_result_z_t0_saturated_d, ~ds_stall_i, clk)
    `FFLNR(mult_result_z_t1_saturated_q, mult_result_z_t1_saturated_d, ~ds_stall_i, clk)

    `FFLNR(swap_min_max_q3, swap_min_max_q2, ~ds_stall_i, clk)
    `FFLNR(div_by_zero_q3, div_by_zero_q2, ~ds_stall_i, clk)
    `FFLNR(ray_orig_inside_bbox_q3, ray_orig_inside_bbox_q2, ~ds_stall_i, clk)

    `FFLNR(last_times_q3, last_times_q2, ~ds_stall_i, clk)

    `FFLSR(vld_q3, vld_q2, ~ds_stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 4 OF 5
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    logic signed [29:0] t0x;  // SQ13.16
    logic signed [29:0] t1x;  // SQ13.16
    logic signed [29:0] t0y;  // SQ13.16
    logic signed [29:0] t1y;  // SQ13.16
    logic signed [29:0] t0z;  // SQ13.16
    logic signed [29:0] t1z;  // SQ13.16

    logic signed [29:0] tmin_x_d, tmin_x_q; // SQ13.16
    logic signed [29:0] tmax_x_d, tmax_x_q; // SQ13.16
    logic signed [29:0] tmin_y_d, tmin_y_q; // SQ13.16
    logic signed [29:0] tmax_y_d, tmax_y_q; // SQ13.16
    logic signed [29:0] tmin_z_d, tmin_z_q; // SQ13.16
    logic signed [29:0] tmax_z_d, tmax_z_q; // SQ13.16

    logic        [2:0] ray_orig_inside_bbox_q4;
    logic        [2:0] div_by_zero_q4;

    range_t      last_times_q4;

    logic              vld_q4;

    // set hit distance to +/-infinity if there is division by 0
    assign t0x = div_by_zero_q3[0] ? NEGATIVE_INFINITY_SQ13_16 : mult_result_x_t0_saturated_q;
    assign t1x = div_by_zero_q3[0] ? INFINITY_SQ13_16 : mult_result_x_t1_saturated_q;
    assign t0y = div_by_zero_q3[1] ? NEGATIVE_INFINITY_SQ13_16 : mult_result_y_t0_saturated_q;
    assign t1y = div_by_zero_q3[1] ? INFINITY_SQ13_16 : mult_result_y_t1_saturated_q;
    assign t0z = div_by_zero_q3[2] ? NEGATIVE_INFINITY_SQ13_16 : mult_result_z_t0_saturated_q;
    assign t1z = div_by_zero_q3[2] ? INFINITY_SQ13_16 : mult_result_z_t1_saturated_q;

    assign tmin_x_d = swap_min_max_q3[0] ? t1x : t0x;
    assign tmax_x_d = swap_min_max_q3[0] ? t0x : t1x;

    assign tmin_y_d = swap_min_max_q3[1] ? t1y : t0y;
    assign tmax_y_d = swap_min_max_q3[1] ? t0y : t1y;

    assign tmin_z_d = swap_min_max_q3[2] ? t1z : t0z;
    assign tmax_z_d = swap_min_max_q3[2] ? t0z : t1z;

    `FFLNR(tmin_x_q, tmin_x_d, ~ds_stall_i, clk)
    `FFLNR(tmax_x_q, tmax_x_d, ~ds_stall_i, clk)
    `FFLNR(tmin_y_q, tmin_y_d, ~ds_stall_i, clk)
    `FFLNR(tmax_y_q, tmax_y_d, ~ds_stall_i, clk)
    `FFLNR(tmin_z_q, tmin_z_d, ~ds_stall_i, clk)
    `FFLNR(tmax_z_q, tmax_z_d, ~ds_stall_i, clk)

    `FFLNR(div_by_zero_q4, div_by_zero_q3, ~ds_stall_i, clk)
    `FFLNR(ray_orig_inside_bbox_q4, ray_orig_inside_bbox_q3, ~ds_stall_i, clk)

    `FFLNR(last_times_q4, last_times_q3, ~ds_stall_i, clk)

    `FFLSR(vld_q4, vld_q3, ~ds_stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 5 OF 5
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    logic signed [29:0] time_upper_bound_d; // SQ13.16
    logic signed [29:0] time_lower_bound_d; // SQ13.16
    logic               hit_d, hit_q;
    logic signed [29:0] time_lower_d, time_lower_q; // SQ13.16
    logic signed [29:0] time_upper_d, time_upper_q; // SQ13.16

    logic               vld_q5;
    
    assign time_upper_bound_d = (tmax_x_q < tmax_y_q) ? ((tmax_x_q < tmax_z_q) ? tmax_x_q : tmax_z_q) : ((tmax_y_q < tmax_z_q) ? tmax_y_q : tmax_z_q);
    assign time_lower_bound_d = (tmin_x_q > tmin_y_q) ? ((tmin_x_q > tmin_z_q) ? tmin_x_q : tmin_z_q) : ((tmin_y_q > tmin_z_q) ? tmin_y_q : tmin_z_q);

    // check all the conditions that indicate a miss and invert 
    assign hit_d = ~((time_lower_bound_d > time_upper_bound_d) | 
                   (div_by_zero_q4[0] & !ray_orig_inside_bbox_q4[0]) |
                   (div_by_zero_q4[1] & !ray_orig_inside_bbox_q4[1]) |
                   (div_by_zero_q4[2] & !ray_orig_inside_bbox_q4[2]) |
                   (time_lower_bound_d[29] & time_upper_bound_d[29]));

    // if we hit update time lower if it's greater than previous time lower and time upper if it's less than previous time upper.
    // if we miss leave everything the same
    assign time_lower_d = hit_d ? ((time_lower_bound_d > last_times_q4.min) ? time_lower_bound_d : last_times_q4.min) : last_times_q4.min;
    assign time_upper_d = hit_d ? ((time_upper_bound_d < last_times_q4.max) ? time_upper_bound_d : last_times_q4.max) : last_times_q4.max; 

    `FFLNR(hit_q, hit_d, ~ds_stall_i, clk)
    `FFLNR(time_lower_q, time_lower_d, ~ds_stall_i, clk)
    `FFLNR(time_upper_q, time_upper_d, ~ds_stall_i, clk)

    `FFLSR(vld_q5, vld_q4, ~ds_stall_i, '0, clk, rst)

    assign ds_hit_o = hit_q;
    assign ds_times_o.min = time_lower_q;
    assign ds_times_o.max = time_upper_q;

    assign ds_vld_o = vld_q5;
    assign us_stall_o = ds_stall_i;
        
endmodule
