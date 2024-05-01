`timescale 1ps/1ps

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

    output ray generated_ray
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
    wire [25:0] rand_x = {pixel_x, offset_x};   // [0, 800)
    wire [25:0] rand_y = {pixel_y, offset_y};   // [0, 600)

    wire [33:0] mult_result_x;
    wire [33:0] mult_result_y;

    // CONSTANTS TO MULTIPLY PIXEL SCREEN COORDINATES BY
    // this constant accounts for both normalization (dividing by screen width and height)
    // and transforming to camera space. I plan to have the resolution, aspect ration, and
    // camera FOV constant, so this can be just one combined constant. Here is the algorithm 
    // for transforming to camera space based on FOV and aspect ratio

    // float vert_fov_rad = vert_fov * PI_F / 180.0;

    //// calculate dimensions of sensor plane using camera FOV
    // float sensor_plane_height =  2.0f * atan(vert_fov_rad); // sensor plane is 1 unit away in Z direction
    // float sensor_plane_width = aspect_ratio * sensor_plane_height;

    //// we now want to transform the normalized screen space [0, 1]^2 coords to camera space
    //// to do this, we multiply our screen_coord by the desired width/height, then shift by half the width and height
    // Vec2 scale(sensor_plane_width, sensor_plane_height);
    // Vec2 shift(sensor_plane_width*0.5f, sensor_plane_height*0.5f);

    // Vec2 camera_xy = (screen_coord * scale) - shift;    

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
    wire signed [18:0] camera_space_x = mult_result_x[33:16] - screen_to_camera_shift_x;  // Q3.16
    wire signed [18:0] camera_space_y = mult_result_y[33:16] - screen_to_camera_shift_y;  // Q3.16

    // set output ray origin
    // by default camera position is the origin
    assign generated_ray.orig = point_default;

    // set output ray direction
    assign generated_ray.dir.x = camera_space_x;
    assign generated_ray.dir.y = camera_space_y;
    assign generated_ray.dir.z = `NEGATIVE_ONE;

    // TODO: In the future, I should add a camera to world space transform here to 
    // support various camera positions. This will require changing bit widths, and
    // potentially the use of certain Xilinx IP cores which are constrained to lower
    // bit widths, such as the DSP macro
    
endmodule