`timescale 1ns/1ps

`include "../data_macros.sv"

/*
This module outputs a ray from the scene camera at (0, 0, 0) to a randomly sampled point
within the given pixel x and y values

THE LATENCY OF THIS MODULE IS 4 CYCLES
ray appears at output 4 cycles after pixels indices arrive at input.

*/
module generate_ray (
    input wire clk,
    input wire rst_n,
    input wire stall,
    input wire [9:0] pixel_x,   // [0, 799]
    input wire [9:0] pixel_y,   // [0, 599]
    input wire pixel_valid,

    output ray generated_ray,
    output wire ray_valid
);

    localparam [16:0] screen_to_camera_shift_x = 17'd77321;
    localparam [15:0] screen_to_camera_shift_y = 16'd57991;

    // prng signals
    wire [15:0] offset_x;   // [0, 1)
    wire [15:0] offset_y;   // [0, 1)

    // prng for x offset
    xor_prng #(
        .SEED(16'h1ACE)
    ) prng_x (
        .clk(clk),
        .rst_n(rst_n),
        .enable(~stall),

        .rand_num(offset_x)
    );

    // prng for y offset
    xor_prng #(
        .SEED(16'hC0DE)
    ) prng_y (
        .clk(clk),
        .rst_n(rst_n),
        .enable(~stall),

        .rand_num(offset_y)
    );

    // random, not normalized pixel sample locations
    wire [25:0] rand_x = {pixel_x, offset_x};   // [0, 800), Q10.16
    wire [25:0] rand_y = {pixel_y, offset_y};   // [0, 600), Q10.16

    wire [33:0] mult_result_x; // Q10.16 * Q0.8 constant = Q10.24
    wire [33:0] mult_result_y; // Q10.16 * Q0.8 constant = Q10.24

    // CONSTANTS TO MULTIPLY PIXEL SCREEN COORDINATES BY

    // Vertical FOV = 70 degrees
    // Aspect Ratio = 4:3
    // Resolution = 800 x 600

    // camera_space_x = ((pixel_x + random_offset_x) / screen_width) * sensor_plane_width - (sensor_plane_width / 2)
    // camera_space_y = ((pixel_y + random_offset_y) / screen_height) * sensor_plane_height - (sensor_plane_height / 2)

    // This formula:
    //     - applies random pixel offset to screen space coordinates
    //     - normalizes to [0, 1] by dividing by screen width/height
    //     - scales to camera sensor plane size based on FOV and aspect ratio
    //     - shifts to center around (0, 0) in camera space

    // float vert_fov_rad = vert_fov * PI_F / 180.0;

    // float sensor_plane_height =  2.0f * atan(vert_fov_rad); // sensor plane is 1 unit away in Z direction
    // float sensor_plane_width = aspect_ratio * sensor_plane_height;

    // We then convert to fixed point with 16 fractional bits by left shifting by 16 bits (multiplying by 2^16)

    // constant coefficient multiplier with 193 (fixed point representation of screen space to
    // camera space scale constant with 16 fractional bits)
    pixel_sampler_mult_x pixel_sampler_mult_x_i (
        .CLK(clk),          // input wire CLK
        .A(rand_x),         // input wire [25 : 0] A
        .CE(~stall),        // input wire CE
        .P(mult_result_x)   // output wire [33 : 0] P
    );

    // constant coefficient multiplier with 193 (fixed point representation of screen space to
    // camera space scale constant with 16 fractional bits)
    pixel_sampler_mult_y pixel_sampler_mult_y_i (
        .CLK(clk),          // input wire CLK
        .A(rand_y),         // input wire [25 : 0] A
        .CE(~stall),        // input wire CE
        .P(mult_result_y)   // output wire [33 : 0] P
    );

    // need to right shift the mult result back by 16 bits for proper fixed point interpretation before shifting
    wire signed [18:0] camera_space_x = mult_result_x[33:16] - screen_to_camera_shift_x;  // Sign bit + Q2.16
    wire signed [18:0] camera_space_y = mult_result_y[33:16] - screen_to_camera_shift_y;  // Sign bit + Q2.16

    // set output ray origin
    // by default camera position is the origin
    assign generated_ray.orig = point_default;

    // set output ray direction
    assign generated_ray.dir.x = camera_space_x;
    assign generated_ray.dir.y = camera_space_y;
    assign generated_ray.dir.z = `NEGATIVE_ONE;

    /////////////////////////////////////////////////////////////////////////
    // valid signal pipeline
    /////////////////////////////////////////////////////////////////////////
    reg [4:0] ray_valid_pipe;

    `FF_EN(clk, rst_n, 5'd0, ~stall, ray_valid_pipe, {ray_valid_pipe[3:0], pixel_valid})
    assign ray_valid = ray_valid_pipe[4];

    // TODO: In the future, I should add a camera to world space transform here to 
    // support various camera positions. This will require changing bit widths, and
    // potentially the use of certain Xilinx IP cores which are constrained to lower
    // bit widths, such as the DSP macro
    
endmodule