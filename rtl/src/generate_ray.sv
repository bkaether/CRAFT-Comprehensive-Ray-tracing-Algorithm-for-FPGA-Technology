`timescale 1ns/1ps

`include "ff_macros.svh"

/*
This module outputs a ray from the scene camera at (0, 0, 0) to a randomly sampled point
within the given pixel x and y values

THE LATENCY OF THIS MODULE IS X CYCLES TODO: document proper latency after norm module is done
ds_ray_o appears at output X cycles after pixels indices arrive at input.

Communicates via a valid/ready handshake (~ds_stall_i and ~us_stall_o act as ready) with adjacent blocks. A valid ray output will hold 
until accepted by downstream block (ds_stall_i released). Similarly, a new pixel will not be accepted into the generate_ray pipeline
while us_stall_o is asserted. It is the job of the upstream block to hold its pixel during a stall. us_stall_o is just a passthrough
of ds_stall_i.

This module matches the software model, which uses y=0 as the bottom row of the image, which is likely the opposite
of the hardware frame buffer, so the frame buffer should write to addresses (PIXEL_HEIGHT-1) - us_pixel_y_i for a proper image

*/
module generate_ray 
    import data_structs_pkg::*;
(
    input wire clk,
    input wire rst,

    // upstream interface
    // data
    input  wire [9:0] us_pixel_x_i,   // [0, 799]
    input  wire [9:0] us_pixel_y_i,   // [0, 599]
    // control
    input  wire       us_vld_i,
    output wire       us_stall_o,

    // downstream interface
    // data
    output ray  ds_ray_o,
    // control
    output wire ds_vld_o,
    input  wire ds_stall_i
);

    // prng signals
    wire [15:0] offset_x;   // [0, 1)
    wire [15:0] offset_y;   // [0, 1)

    // prng for x offset
    xor_prng #(
        .SEED(16'h1ACE)
    ) u_prng_x (
        .clk(clk),
        .rst(rst),
        .en_i(~ds_stall_i && us_vld_i), // only advance prng when we need a new value

        .rand_num_o(offset_x)
    );

    // prng for y offset
    xor_prng #(
        .SEED(16'hC0DE)
    ) u_prng_y (
        .clk(clk),
        .rst(rst),
        .en_i(~ds_stall_i && us_vld_i), // only advance prng when we need a new value

        .rand_num_o(offset_y)
    );

    // random, not normalized pixel sample locations
    wire [25:0] rand_x = {us_pixel_x_i, offset_x};   // [0, 800), Q10.16
    wire [25:0] rand_y = {us_pixel_y_i, offset_y};   // [0, 600), Q10.16

    // CONSTANTS TO MULTIPLY PIXEL SCREEN COORDINATES BY

    // Vertical FOV = 70 degrees
    // Aspect Ratio = 4:3
    // Resolution = 800 x 600

    // camera_space_x = ((us_pixel_x_i + random_offset_x) / screen_width) * sensor_plane_width - (sensor_plane_width / 2)
    // camera_space_y = ((us_pixel_y_i + random_offset_y) / screen_height) * sensor_plane_height - (sensor_plane_height / 2)

    // float sensor_plane_height =  2.0f * tan(vert_fov_rad/2.0); // sensor plane is 1 unit away in Z direction
    // float sensor_plane_width = aspect_ratio * sensor_plane_height;

    // float vert_fov_rad = vert_fov * PI_F / 180.0;

    // This formula:
    //     - applies random pixel offset to screen space coordinates
    //     - normalizes to [0, 1] by dividing by screen width/height
    //     - scales to camera sensor plane size based on FOV and aspect ratio
    //     - shifts to center around (0, 0) in camera space

    // the final constants to multiply by are (sensor_plane_width / screen_width) and (sensor_plane_height / screen_height)
    // with my numbers, they both come out to 0.002334. I decided that I wanted 16 bits of fractional precision to represent this number
    // to maintain good accuracy, so multiply by 2^16 to get 153. Only 8 actual bits are needed to store this number for the multiply.
    localparam logic        [7:0]  SCALING_CONST = 153;
    localparam logic signed [18:0] SCREEN_TO_CAMERA_SHIFT_X = 19'sd61185;
    localparam logic signed [18:0] SCREEN_TO_CAMERA_SHIFT_Y = 19'sd45889;

    // to store the full result we need Q10.16 * Q8.0 = Q18.16 = 34 bits
    wire [33:0] mult_result_x;
    wire [33:0] mult_result_y;

    assign mult_result_x = rand_x * SCALING_CONST;
    assign mult_result_y = rand_y * SCALING_CONST;
    
    // need to right shift the mult result back by 16 bits (because of the 2^16 multiplied by earleir to get 153) for proper fixed point
    // interpretation before subtracting the camera shift. This means Q18.16 -> Q 2.32. We only want 16 bits of fractional precision so
    // we can just take the upper 18 bits, then add an extra bit for the signed bit
    wire signed [18:0] signed_mult_result_x = $signed({1'b0, mult_result_x[33:16]});
    wire signed [18:0] signed_mult_result_y = $signed({1'b0, mult_result_y[33:16]});

    wire signed [18:0] camera_space_x_d = signed_mult_result_x - SCREEN_TO_CAMERA_SHIFT_X;  // Sign bit + Q2.16 (keep 16 fractional bits and trim unused integer bits)
    wire signed [18:0] camera_space_y_d = signed_mult_result_y - SCREEN_TO_CAMERA_SHIFT_Y;  // Sign bit + Q2.16 (keep 16 fractional bits and trim unused integer bits)

    // output registers
    reg signed [18:0] camera_space_x_q;
    reg signed [18:0] camera_space_y_q;
    reg               ds_vld_q;

    `FFLNR(camera_space_x_q, camera_space_x_d, ~ds_stall_i, clk)
    `FFLNR(camera_space_y_q, camera_space_y_d, ~ds_stall_i, clk)
    `FFLSR(ds_vld_q, us_vld_i, ~ds_stall_i, '0, clk, rst)

    // we now need to normalize the ray directions. With our chosen FOV (70) and aspect ratio (4/3), the full range of the normalization function
    // 1 / (x^2 + y^2 + 1) is [1, 2.362), which means we are in a good position to use a look up table with linear interpolation to get good
    // accuracy with reasonable hardware cost. See generate_ray_norm.sv for more info

    // set output ray origin
    // by default camera position is the origin
    assign ds_ray_o.orig = POINT_DEFAULT;

    // set output ray direction
    assign ds_ray_o.dir.x = camera_space_x_q;
    assign ds_ray_o.dir.y = camera_space_y_q;
    assign ds_ray_o.dir.z = NEGATIVE_ONE_Q12_16; // ray points into the scene, which is in the negative z direction

    assign ds_vld_o = ds_vld_q;

    // stall passthrough
    assign us_stall_o = ds_stall_i;

    // TODO: In the future, I should add a camera to world space transform here to 
    // support various camera positions. This will require changing bit widths, and
    // potentially the use of certain Xilinx IP cores which are constrained to lower
    // bit widths, such as the DSP macro

    //////////////////////////////////////////////////////////////////////////
    // assertions
    //////////////////////////////////////////////////////////////////////////
`ifndef SYNTHESIS

    property p_ray_held_during_stall;
        @(posedge clk) disable iff (rst)
        (ds_vld_o && ds_stall_i) |=> (ds_vld_o && $stable(ds_ray_o));     // $stable() checks that its argument is the same as it was in the previous cycle
    endproperty

    a_ray_held_during_stall: assert property (p_ray_held_during_stall)
        else $error("Ray output was not held stable during ds_stall_i condition");

    property p_ray_not_valid_on_rst;
        @(posedge clk)
        rst |=> !ds_vld_o;
    endproperty

    a_ray_not_valid_on_rst: assert property (p_ray_not_valid_on_rst)
        else $error("ds_vld_o asserted during or after reset");

`endif
    
endmodule