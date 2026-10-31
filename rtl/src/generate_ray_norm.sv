`timescale 1ns/1ps

`include "ff_macros.svh"


/*
This module is used to normalize the raw ray directions that are calculated in genereate_ray.  With our chosen FOV (70)
and aspect ratio (4/3), we will use a look up table to map s = (x² + y² + 1) to the output 1 / √(x² + y² + 1).
z² is always 1 because the z direction of all generated rays is -1. The input range of s is [1, 2.362), which means we
are in a good position to use a look up table with linear interpolation to get great accuracy with reasonable hardware cost.

We will represent a larger input range [1, 4) to support potential changes to aspect ratio and FOV in the future. For the input
range [1, 4), the full output range is (0.5, 1]. We want 16 fractional bits of precision, so aim for accuracy within 2⁻¹⁷. To
calculate how many table entries we need we can use the following equations.

straight line error modeling a curve:

actual_error <= f'' · h² / 8  

(where f is our function 1/sqrt(s) and f'' is the curvature of that function)

f''(s) = (3/4) · s^(−5/2)

we want the largest possible error to fit within our constraints, and largest error occurs at s = 1 and f''(s) = 0.75, so

max_actual_error = 0.75 · h² / 8 <= target_error = 2⁻¹⁷   

h <= √(8 · target_error / 0,75) where h is spacing between entries

num_intervals = range / spacing = (4-1) / h

with target error 2⁻¹⁷:
num_intervals is 333, which we can round up to 512 for easier interpolating

THE LATENCY OF THIS MODULE IS 4 CYCLES
*/
module generate_ray_norm
    import data_structs_pkg::*;
(
    input wire clk,
    input wire rst,

    input wire signed [18:0] x_i,   // SQ2.16
    input wire signed [18:0] y_i,   // SQ2.16
    input wire vld_i,
    input wire stall_i,

    output wire signed [17:0] x_norm_o,   // SQ1.16 - normalized vector componenets can be [-1, 1]
    output wire signed [17:0] y_norm_o,   // SQ1.16 - normalized vector componenets can be [-1, 1]
    output wire signed [17:0] z_norm_o,   // SQ1.16 - normalized vector componenets can be [-1, 1]
    output wire vld_o
);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 1 OF 4
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    localparam logic signed [37:0] ONE_Q6_32 = (38'sd1 << 32);  // Q6.32

    logic signed [37:0] x_sq;   // SQ5.32
    logic signed [37:0] y_sq;   // SQ5.32
    logic signed [37:0] s;      // SQ5.32
    logic        [21:0] s_trimmed_d; // Q2.20
    logic        [21:0] s_trimmed_q; // Q2.20
    logic signed [18:0] x_q1; // SQ2.16
    logic signed [18:0] y_q1; // SQ2.16
    logic               vld_q1;
    
    // (SQ2.16) * (SQ2.16) = SQ5.32
    assign x_sq = x_i * x_i;
    assign y_sq = y_i * y_i;
    
    // s = x² + y² + 1 -> SQ5.32
    assign s = x_sq + y_sq + ONE_Q6_32;

    // based on pixel range, the possible range of S is [1, 4)
    // we can trim off unused sign/integer bits and reduce unnecessary precision
    // trim to Q2.20
    assign s_trimmed_d = s[33:12]; 

    `FFLNR(s_trimmed_q, s_trimmed_d, ~stall_i, clk)
    `FFLNR(x_q1, x_i, ~stall_i, clk)
    `FFLNR(y_q1, y_i, ~stall_i, clk)
    `FFLSR(vld_q1, vld_i, ~stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 2 OF 4
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // look up table which stores the normalization values 1/√(s) for a givin value of s = x² + y² + 1
    // input  s_trimmed      -> [1, 4),   Q2.20 format
    // output {lut_entry, entry_difference} with
    //      lut_entry           -> (0.5, 1], Q1.16 format
    //      entry_difference -> (0, 1),   Q0.16 format

    // entry_difference, the difference between the current entry and the next entry, is always positive because 1/√(s) is a strictly decreasing
    // function. This difference is needed for interpolation, and it's cheaper to store in the table than to do a subtraction for every read.
    // It requires a only 8 bits to store because the largest difference between entries in the table is 0.00388 (no difference will use the first
    // 8 fractional bits of the Q0.16 format
    (* rom_style = "distributed" *)
    logic [24:0] norm_lut [512];   // {Q1.16, 8 bits for difference}

    // populate the lut from the table generation script's output
    // file format: 512 lines, one 7-digit hex value per line ({value, difference}), line i = address i
    initial begin
        $readmemh("norm_lut.mem", norm_lut);
    end

    logic [24:0] lut_read;         // {Q1.16, 8 bits for difference}
    logic [8:0]  lut_addr;
    logic [19:0] s_interp_d;         // Q0.20
    logic [19:0] s_interp_q;         // Q0.20
    logic [16:0] lut_entry_d;        // Q1.16
    logic [16:0] lut_entry_q;        // Q1.16   
    logic [15:0] entry_difference_d; // Q0.16
    logic [15:0] entry_difference_q; // Q0.16
    logic signed [18:0] x_q2;        // SQ2.16
    logic signed [18:0] y_q2;        // SQ2.16
    logic               vld_q2;

    // s_trimmed_q = {lut_addr, s_interp}
    // lut_read    = {lut_entry, entry_difference}

    // the 9 MSBs of our input s_trimmed are used to index into the lut
    // these 9 MSBs include 7 fractional bits, which is important to remember for padding the remaining bits of 
    // s_trimmed so they are used correctly for interpolation
    assign lut_addr = s_trimmed_q[21:13];

    // the remaining LSBs are used for interpolation
    // must pad with 0s in the first 7 fractional bits that were used for the addr to maintain correct fxpt value
    assign s_interp_d = {7'b0, s_trimmed_q[12:0]};

    // read data from lut
    assign lut_read = norm_lut[lut_addr];
    assign lut_entry_d = lut_read[24:8];
    assign entry_difference_d = {8'b0, lut_read[7:0]};

    `FFLNR(s_interp_q, s_interp_d, ~stall_i, clk)
    `FFLNR(lut_entry_q, lut_entry_d, ~stall_i, clk)
    `FFLNR(entry_difference_q, entry_difference_d, ~stall_i, clk)
    `FFLNR(x_q2, x_q1, ~stall_i, clk)
    `FFLNR(y_q2, y_q1, ~stall_i, clk)
    `FFLSR(vld_q2, vld_q1, ~stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 3 OF 4
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    logic [35:0] interp_val;    // Q0.36
    logic [36:0] norm_div;      // Q1.36
    logic signed [37:0] norm_div_signed;    // SQ1.36
    logic signed [21:0] norm_div_trimmed_d; // SQ1.20
    logic signed [21:0] norm_div_trimmed_q; // SQ1.20
    logic signed [18:0] x_q3;        // SQ2.16
    logic signed [18:0] y_q3;        // SQ2.16
    logic               vld_q3;

    // the bit range of s_trimmed (Q2.20) supports the range of [0, 4) with 512 entries, so spacing is (4-0)/512 = 1/128
    // it is crucial that the spacing term is a power of 2 so that the operation can be done with a shift
    // linear interpolation from lut entries for a decreasing function can be calculated as:
    //      result = selected_entry - interpolation_term * ((selected_entry - next_entry)/spacing)
    assign interp_val = s_interp_q * (entry_difference_q << 7); // Q0.20 * Q0.16 = Q0.36

    // pad lut_entry from Q1.16 to Q1.36 for equal width subtraction, interpolate downwards because function is decreasing
    assign norm_div = {lut_entry_q, 20'b0} - interp_val; 
    assign norm_div_signed = $signed({1'b0, norm_div}); // SQ1.36

    // trim bits down before another multiply to keep sizes reasonable
    assign norm_div_trimmed_d = norm_div_signed[37:16];   // SQ1.20

    `FFLNR(norm_div_trimmed_q, norm_div_trimmed_d, ~stall_i, clk)
    `FFLNR(x_q3, x_q2, ~stall_i, clk)
    `FFLNR(y_q3, y_q2, ~stall_i, clk)
    `FFLSR(vld_q3, vld_q2, ~stall_i, '0, clk, rst)

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOGIC STAGE 4 OF 4
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    logic signed [40:0] x_norm_full;    // SQ4.36
    logic signed [40:0] y_norm_full;    // SQ4.36
    logic signed [21:0] z_norm_full;    // SQ1.20
    logic signed [17:0] x_norm_d;       // SQ1.16 - normalized vector componenets can be [-1, 1]
    logic signed [17:0] y_norm_d;       // SQ1.16 - normalized vector componenets can be [-1, 1]
    logic signed [17:0] z_norm_d;       // SQ1.16 - normalized vector componenets can be [-1, 1]
    logic signed [17:0] x_norm_q;       // SQ1.16 - normalized vector componenets can be [-1, 1]
    logic signed [17:0] y_norm_q;       // SQ1.16 - normalized vector componenets can be [-1, 1]
    logic signed [17:0] z_norm_q;       // SQ1.16 - normalized vector componenets can be [-1, 1]
    logic               vld_q4;

    // normalize x, y, and z with final multiply (z is always -1 in camera space)
    assign x_norm_full = x_q3 * norm_div_trimmed_q;   // SQ2.16 * SQ1.20 = SQ4.36
    assign y_norm_full = y_q3 * norm_div_trimmed_q;   // SQ2.16 * SQ1.20 = SQ4.36
    assign z_norm_full = -norm_div_trimmed_q;         // SQ1.20

    // trim for final output
    assign x_norm_d = {x_norm_full[40], x_norm_full[36:20]};
    assign y_norm_d = {y_norm_full[40], y_norm_full[36:20]};
    assign z_norm_d = z_norm_full[21:4];

    `FFLNR(x_norm_q, x_norm_d, ~stall_i, clk)
    `FFLNR(y_norm_q, y_norm_d, ~stall_i, clk)
    `FFLNR(z_norm_q, z_norm_d, ~stall_i, clk)
    `FFLSR(vld_q4, vld_q3, ~stall_i, '0, clk, rst)

    assign x_norm_o = x_norm_q;
    assign y_norm_o = y_norm_q;
    assign z_norm_o = z_norm_q;
    assign vld_o = vld_q4;    


    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // ASSERTIONS
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
`ifndef SYNTHESIS

    property p_lut_input_bound;
        @(posedge clk) disable iff (rst)
        vld_i |-> ((s >= 38'sh100000000) && (s < 38'sh400000000)); // (s >= 1) && (s < 4) in SQ5.32
    endproperty

    a_lut_input_bound: assert property (p_lut_input_bound)
        else $fatal(1, "s outside the norm LUT’s supported range [1, 4): the FOV or aspect ratio produces directions the table does not cover.");

`endif

endmodule