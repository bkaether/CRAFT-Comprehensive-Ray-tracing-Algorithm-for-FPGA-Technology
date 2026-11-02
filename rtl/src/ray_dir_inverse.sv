`timescale 1ns/1ps

`include "ff_macros.svh"

/*
This module precomputes the inverse of the direction of the normalized generated ray using a LUT for repeated use when
traversing the BVH.

for each axis, 1/dir = (−1)^sign × mantissa × 2^shift; when div_by_zero is set, mantissa and shift are invalid.

THE LATENCY OF THIS MODULE IS 3 CYCLES
*/
module ray_dir_inverse 
    import data_structs_pkg::*;
(
    input wire clk,
    input wire rst,

    // upstream interface
    // data
    input unit_vec3_t us_unit_ray_dir_i,    // SQ1.16 per x/y/z component
    // control
    input  wire us_vld_i,
    output wire us_stall_o,

    // downstream interface
    // data
    output wire [16:0]  ds_inv_dir_mantissa_x_o,   // Q1.16 per x/y/z component
    output wire [16:0]  ds_inv_dir_mantissa_y_o,   // Q1.16 per x/y/z component
    output wire [16:0]  ds_inv_dir_mantissa_z_o,   // Q1.16 per x/y/z component

    output wire         ds_inv_dir_sign_x_o,
    output wire         ds_inv_dir_sign_y_o,
    output wire         ds_inv_dir_sign_z_o,

    output wire         ds_inv_dir_div_by_zero_x_o,
    output wire         ds_inv_dir_div_by_zero_y_o,
    output wire         ds_inv_dir_div_by_zero_z_o,

    output wire [4:0]   ds_inv_dir_shift_x_o,
    output wire [4:0]   ds_inv_dir_shift_y_o,
    output wire [4:0]   ds_inv_dir_shift_z_o,

    // control
    output wire         ds_vld_o,
    input  wire         ds_stall_i
    
);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 1 OF 3
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Calculating 1/dir with a LUT requires formatting dir as dir = m * 2^-k, so 1/dir = (1/m) * 2^k
    // this means that k is the shift value and m is a value with greatly reduced possible range, making it a better fit for a lookup
    // we count the leading zeros of |dir| to find k, then left shift dir by that amount to get m with the MSB always set to 1. This 
    // guarantees m in the range [1, 2) and therefore 1/m in the range (0.5, 1]. These are much better ranges for approximation using a LUT
    // the sign bit itself is tracked separately

    localparam int ABS_DIR_WIDTH = $bits(us_unit_ray_dir_i.x) - 1;

    logic signed [17:0] dir_x, dir_y, dir_z;             // SQ1.16
    logic               sign_x_d, sign_y_d, sign_z_d;
    logic               sign_x_q1, sign_y_q1, sign_z_q1;
    logic        [17:0] abs_dir_x, abs_dir_y, abs_dir_z; // Q2.16
    logic        [16:0] abs_dir_x_trimmed, abs_dir_y_trimmed, abs_dir_z_trimmed; // Q1.16
    logic        [4:0]  k_x_d, k_y_d, k_z_d;
    logic        [4:0]  k_x_q1, k_y_q1, k_z_q1;
    logic        [16:0] m_x_d, m_y_d, m_z_d;             // Q1.16
    logic        [16:0] m_x_q, m_y_q, m_z_q;             // Q1.16
    logic               vld_q1;

    // dir_* -> [-1, 1]
    assign dir_x = us_unit_ray_dir_i.x;
    assign dir_y = us_unit_ray_dir_i.y;
    assign dir_z = us_unit_ray_dir_i.z;

    assign sign_x_d = dir_x[17];
    assign sign_y_d = dir_y[17];
    assign sign_z_d = dir_z[17];

    // |dir_*| -> [0, 1]
    assign abs_dir_x = sign_x_d ? -dir_x : dir_x;
    assign abs_dir_y = sign_y_d ? -dir_y : dir_y;
    assign abs_dir_z = sign_z_d ? -dir_z : dir_z;

    // trim unused sign bit to Q1.16
    assign abs_dir_x_trimmed = abs_dir_x[16:0];
    assign abs_dir_y_trimmed = abs_dir_y[16:0];
    assign abs_dir_z_trimmed = abs_dir_z[16:0];

    leading_zero_count #(
        .WIDTH(ABS_DIR_WIDTH)
    ) u_leading_zero_count_x (
        .num_i(abs_dir_x_trimmed),

        .count_o(k_x_d)
    );

    leading_zero_count #(
        .WIDTH(ABS_DIR_WIDTH)
    ) u_leading_zero_count_y (
        .num_i(abs_dir_y_trimmed),

        .count_o(k_y_d)
    );

    leading_zero_count #(
        .WIDTH(ABS_DIR_WIDTH)
    ) u_leading_zero_count_z (
        .num_i(abs_dir_z_trimmed),

        .count_o(k_z_d)
    );

    // m_* -> [1, 2)
    assign m_x_d = abs_dir_x_trimmed << k_x_d;
    assign m_y_d = abs_dir_y_trimmed << k_y_d;
    assign m_z_d = abs_dir_z_trimmed << k_z_d;

    `FFLNR(m_x_q, m_x_d, ~ds_stall_i, clk)
    `FFLNR(m_y_q, m_y_d, ~ds_stall_i, clk)
    `FFLNR(m_z_q, m_z_d, ~ds_stall_i, clk)

    `FFLNR(k_x_q1, k_x_d, ~ds_stall_i, clk)
    `FFLNR(k_y_q1, k_y_d, ~ds_stall_i, clk)
    `FFLNR(k_z_q1, k_z_d, ~ds_stall_i, clk)

    `FFLNR(sign_x_q1, sign_x_d, ~ds_stall_i, clk)
    `FFLNR(sign_y_q1, sign_y_d, ~ds_stall_i, clk)
    `FFLNR(sign_z_q1, sign_z_d, ~ds_stall_i, clk)

    `FFLSR(vld_q1, us_vld_i, ~ds_stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 2 OF 3
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // look up table which stores the values 1/m for a given value of m
    // input  m_*      -> [1, 2),   Q1.16 format
    // output {lut_entry, entry_difference} with
    //      lut_entry        -> (0.5, 1], Q1.16 format
    //      entry_difference -> (0, 1),   Q0.16 format

    // entry_difference, the difference between the current entry and the next entry, is always positive because 1/m is a strictly decreasing
    // function. This difference is needed for interpolation, and it's cheaper to store in the table than to do a subtraction for every read.
    // The largest difference between entries over our range fits in 8 bits (no difference will use the first 8 fractional bits of the Q0.16 format
    (* rom_style = "distributed" *)
    logic [24:0] reciprocal_lut [256];  // {Q1.16, 8 bits for difference}

    // populate the lut from the table generation script's output
    // file format: 256 lines, one 7-digit hex value per line ({value, difference}), line i = address i
    initial begin
        $readmemh("reciprocal_lut.mem", reciprocal_lut);
    end

    logic [7:0]  addr_x, addr_y, addr_z;
    logic [15:0] remainder_x_d, remainder_y_d, remainder_z_d;       // Q0.16
    logic [15:0] remainder_x_q, remainder_y_q, remainder_z_q;       // Q0.16
    logic [24:0] lut_read_x, lut_read_y, lut_read_z;
    logic [16:0] lut_entry_x_d, lut_entry_y_d, lut_entry_z_d;       // Q1.16
    logic [16:0] lut_entry_x_q, lut_entry_y_q, lut_entry_z_q;       // Q1.16
    logic [15:0] entry_diff_x_d, entry_diff_y_d, entry_diff_z_d;    // Q0.16
    logic [15:0] entry_diff_x_q, entry_diff_y_q, entry_diff_z_q;    // Q0.16

    logic        sign_x_q2, sign_y_q2, sign_z_q2;
    logic [4:0]  k_x_q2, k_y_q2, k_z_q2;
    logic        vld_q2;

    // we don't need MSB of Q1.16 for the addr because it's always 1 after the k shift
    assign addr_x = m_x_q[15:8];
    assign addr_y = m_y_q[15:8];
    assign addr_z = m_z_q[15:8];

    assign lut_read_x = reciprocal_lut[addr_x];
    assign lut_read_y = reciprocal_lut[addr_y];
    assign lut_read_z = reciprocal_lut[addr_z];

    assign lut_entry_x_d = lut_read_x[24:8];
    assign lut_entry_y_d = lut_read_y[24:8];
    assign lut_entry_z_d = lut_read_z[24:8];

    assign entry_diff_x_d = {8'b0, lut_read_x[7:0]};
    assign entry_diff_y_d = {8'b0, lut_read_y[7:0]};
    assign entry_diff_z_d = {8'b0, lut_read_z[7:0]};

    // pad 0s before the remainder for the fractional bits that were given to the address so the remainder is interpreted correctly
    assign remainder_x_d = {8'b0, m_x_q[7:0]};
    assign remainder_y_d = {8'b0, m_y_q[7:0]};
    assign remainder_z_d = {8'b0, m_z_q[7:0]};

    `FFLNR(lut_entry_x_q, lut_entry_x_d, ~ds_stall_i, clk)
    `FFLNR(lut_entry_y_q, lut_entry_y_d, ~ds_stall_i, clk)
    `FFLNR(lut_entry_z_q, lut_entry_z_d, ~ds_stall_i, clk)

    `FFLNR(remainder_x_q, remainder_x_d, ~ds_stall_i, clk)
    `FFLNR(remainder_y_q, remainder_y_d, ~ds_stall_i, clk)
    `FFLNR(remainder_z_q, remainder_z_d, ~ds_stall_i, clk)

    `FFLNR(entry_diff_x_q, entry_diff_x_d, ~ds_stall_i, clk)
    `FFLNR(entry_diff_y_q, entry_diff_y_d, ~ds_stall_i, clk)
    `FFLNR(entry_diff_z_q, entry_diff_z_d, ~ds_stall_i, clk)

    `FFLNR(sign_x_q2, sign_x_q1, ~ds_stall_i, clk)
    `FFLNR(sign_y_q2, sign_y_q1, ~ds_stall_i, clk)
    `FFLNR(sign_z_q2, sign_z_q1, ~ds_stall_i, clk)

    `FFLNR(k_x_q2, k_x_q1, ~ds_stall_i, clk)
    `FFLNR(k_y_q2, k_y_q1, ~ds_stall_i, clk)
    `FFLNR(k_z_q2, k_z_q1, ~ds_stall_i, clk)

    `FFLSR(vld_q2, vld_q1, ~ds_stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 3 OF 3
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    logic [31:0] mult_term_x, mult_term_y, mult_term_z;          // Q0.32
    logic [32:0] abs_inv_m_x, abs_inv_m_y, abs_inv_m_z;    // Q1.32
    logic [16:0] inv_m_x_d, inv_m_y_d, inv_m_z_d;          // Q1.16
    logic [16:0] inv_m_x_q, inv_m_y_q, inv_m_z_q;          // Q1.16

    logic        sign_x_q3, sign_y_q3, sign_z_q3;
    logic [4:0]  k_x_q3, k_y_q3, k_z_q3;
    logic        vld_q3;

    assign mult_term_x = (entry_diff_x_q << 8) * remainder_x_q;     // Q0.16 * Q0.16 = Q0.32
    assign mult_term_y = (entry_diff_y_q << 8) * remainder_y_q;     // Q0.16 * Q0.16 = Q0.32
    assign mult_term_z = (entry_diff_z_q << 8) * remainder_z_q;     // Q0.16 * Q0.16 = Q0.32

    // pad both operands to be the same width and fixed point format
    // padding with 16'h8000 allows the later trim back to 16 fractional bits to act as a round instead of a truncate, which reduces error
    assign abs_inv_m_x = {lut_entry_x_q, 16'h8000} - {1'b0, mult_term_x};    // Q1.32 - Q1.32 = Q1.32
    assign abs_inv_m_y = {lut_entry_y_q, 16'h8000} - {1'b0, mult_term_y};    // Q1.32 - Q1.32 = Q1.32
    assign abs_inv_m_z = {lut_entry_z_q, 16'h8000} - {1'b0, mult_term_z};    // Q1.32 - Q1.32 = Q1.32

    // trim to Q1.16
    assign inv_m_x_d = abs_inv_m_x[32:16];
    assign inv_m_y_d = abs_inv_m_y[32:16];
    assign inv_m_z_d = abs_inv_m_z[32:16];

    `FFLNR(inv_m_x_q, inv_m_x_d, ~ds_stall_i, clk)
    `FFLNR(inv_m_y_q, inv_m_y_d, ~ds_stall_i, clk)
    `FFLNR(inv_m_z_q, inv_m_z_d, ~ds_stall_i, clk)

    `FFLNR(sign_x_q3, sign_x_q2, ~ds_stall_i, clk)
    `FFLNR(sign_y_q3, sign_y_q2, ~ds_stall_i, clk)
    `FFLNR(sign_z_q3, sign_z_q2, ~ds_stall_i, clk)

    `FFLNR(k_x_q3, k_x_q2, ~ds_stall_i, clk)
    `FFLNR(k_y_q3, k_y_q2, ~ds_stall_i, clk)
    `FFLNR(k_z_q3, k_z_q2, ~ds_stall_i, clk)

    `FFLSR(vld_q3, vld_q2, ~ds_stall_i, '0, clk, rst)
    
    // assign module outputs
    assign ds_inv_dir_mantissa_x_o = inv_m_x_q;
    assign ds_inv_dir_mantissa_y_o = inv_m_y_q;
    assign ds_inv_dir_mantissa_z_o = inv_m_z_q;

    assign ds_inv_dir_sign_x_o = sign_x_q3;
    assign ds_inv_dir_sign_y_o = sign_y_q3;
    assign ds_inv_dir_sign_z_o = sign_z_q3;

    assign ds_inv_dir_shift_x_o = k_x_q3;
    assign ds_inv_dir_shift_y_o = k_y_q3;
    assign ds_inv_dir_shift_z_o = k_z_q3;

    assign ds_inv_dir_div_by_zero_x_o = (k_x_q3 == ABS_DIR_WIDTH);
    assign ds_inv_dir_div_by_zero_y_o = (k_y_q3 == ABS_DIR_WIDTH);
    assign ds_inv_dir_div_by_zero_z_o = (k_z_q3 == ABS_DIR_WIDTH);

    assign ds_vld_o = vld_q3;
    assign us_stall_o = ds_stall_i;


endmodule