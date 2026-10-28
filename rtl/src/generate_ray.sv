`timescale 1ns/1ps

`include "ff_macros.svh"

/*
This module outputs a ray from the scene camera at (0, 0, 0) to a randomly sampled point
within the given pixel x and y values

THE LATENCY OF THIS MODULE IS MULT_STAGES CYCLES
ray appears at output MULT_STAGES cycles after pixels indices arrive at input.

Communicates via a valid/ready handshake (~stall_in and ~stall_out act as ready) with adjacent blocks. A valid ray output will hold 
until accepted by downstream block (stall_in released). Similarly, a new pixel will not be accepted into the generate_ray pipeline
while stall_out is asserted. It is the job of the upstream block to hold its pixel during a stall. stall_out is just a passthrough
of stall_in.

*/
module generate_ray 
    import data_structs_pkg::*;
#(parameter MULT_STAGES = 1)
(
    input wire clk,
    input wire rst,
    input wire stall_in,
    input wire [9:0] pixel_x,   // [0, 799]
    input wire [9:0] pixel_y,   // [0, 599]
    input wire pixel_valid,

    output ray generated_ray,
    output wire ray_valid,
    output wire stall_out
);

    localparam [16:0] screen_to_camera_shift_x = 17'd61185;
    localparam [15:0] screen_to_camera_shift_y = 16'd45889;

    // prng signals
    wire [15:0] offset_x;   // [0, 1)
    wire [15:0] offset_y;   // [0, 1)

    // prng for x offset
    xor_prng #(
        .SEED(16'h1ACE)
    ) prng_x (
        .clk(clk),
        .rst(rst),
        .enable(~stall_in),

        .rand_num(offset_x)
    );

    // prng for y offset
    xor_prng #(
        .SEED(16'hC0DE)
    ) prng_y (
        .clk(clk),
        .rst(rst),
        .enable(~stall_in),

        .rand_num(offset_y)
    );

    // random, not normalized pixel sample locations
    wire [25:0] rand_x = {pixel_x, offset_x};   // [0, 800), Q10.16
    wire [25:0] rand_y = {pixel_y, offset_y};   // [0, 600), Q10.16

    // CONSTANTS TO MULTIPLY PIXEL SCREEN COORDINATES BY

    // Vertical FOV = 70 degrees
    // Aspect Ratio = 4:3
    // Resolution = 800 x 600

    // camera_space_x = ((pixel_x + random_offset_x) / screen_width) * sensor_plane_width - (sensor_plane_width / 2)
    // camera_space_y = ((pixel_y + random_offset_y) / screen_height) * sensor_plane_height - (sensor_plane_height / 2)

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
    localparam logic [7:0] SCALING_CONST = 153;

    // to store the full result we need Q10.16 * Q8.0 = Q18.16 = 34 bits
    wire [33:0] mult_result_x;
    wire [33:0] mult_result_y;

    assign mult_result_x = rand_x * SCALING_CONST;
    assign mult_result_y = rand_y * SCALING_CONST;
    
    // need to right shift the mult result back by 16 bits (because of the 2^16 multiplied by earleir to get 153)
    // for proper fixed point interpretation before subtracting the camera shift
    wire signed [18:0] camera_space_x = mult_result_x[33:16] - screen_to_camera_shift_x;  // Sign bit + Q2.16 (keep 16 fractional bits and trim unused integer bits)
    wire signed [18:0] camera_space_y = mult_result_y[33:16] - screen_to_camera_shift_y;  // Sign bit + Q2.16 (keep 16 fractional bits and trim unused integer bits)

    // Elaboration-time guard: a depth of 0 would leave no registers at all
    if (MULT_STAGES < 1) begin : g_check_mult_stages
        $error("MULT_STAGES must be at least 1");
    end

    // Index 0 is the combinational input to the pipe (NOT a flop).
    // Indices 1..MULT_STAGES are the pipeline registers.
    logic signed [18:0] camera_space_x_pipe [MULT_STAGES+1];
    logic signed [18:0] camera_space_y_pipe [MULT_STAGES+1];
    logic               ray_valid_pipe      [MULT_STAGES+1];

    assign camera_space_x_pipe[0] = camera_space_x;
    assign camera_space_y_pipe[0] = camera_space_y;
    assign ray_valid_pipe[0]      = pixel_valid;

    for (genvar i = 1; i <= MULT_STAGES; i++) begin : g_camera_space_pipe
        `FFLNR(camera_space_x_pipe[i], camera_space_x_pipe[i-1], ~stall_in, clk)
        `FFLNR(camera_space_y_pipe[i], camera_space_y_pipe[i-1], ~stall_in, clk)
        `FFLSR(ray_valid_pipe[i], ray_valid_pipe[i-1], ~stall_in, '0, clk, rst)
    end : g_camera_space_pipe

    // set output ray origin
    // by default camera position is the origin
    assign generated_ray.orig = POINT_DEFAULT;

    // set output ray direction
    assign generated_ray.dir.x = camera_space_x_pipe[MULT_STAGES];
    assign generated_ray.dir.y = camera_space_y_pipe[MULT_STAGES];
    assign generated_ray.dir.z = NEGATIVE_ONE_Q12_16; // ray points into the scene, which is in the negative z direction

    assign ray_valid = ray_valid_pipe[MULT_STAGES];

    // stall passthrough
    assign stall_out = stall_in;

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
        (ray_valid && stall_in) |=> (ray_valid && $stable(generated_ray));     // $stable() checks that its argument is the same as it was in the previous cycle
    endproperty

    a_ray_held_during_stall: assert property (p_ray_held_during_stall)
        else $error("Ray output was not held stable during stall_in condition");

    property p_ray_not_valid_on_rst;
        @(posedge clk)
        rst |=> !ray_valid;
    endproperty

    a_ray_not_valid_on_rst: assert property (p_ray_not_valid_on_rst)
        else $error("ray_valid asserted during or after reset");

`endif
    
endmodule