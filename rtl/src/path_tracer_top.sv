`timescale 1ns/1ps

`include "ff_macros.svh"

/*
Top level of the path tracer pipeline. Currently chains:

    generate_ray (18 cycles) -> ray_dir_inverse (3 cycles)

Every block uses the standard valid/stall handshake (see doc/naming_conventions.md). Stall is a combinational
passthrough through every block, so ds_stall_i reaches us_stall_o and every pipeline register's enable in the
same cycle.

Outputs: the generated ray (origin + unit direction) and the inverse of its direction, aligned to the same
cycle. For each axis, 1/dir = (-1)^sign * mantissa * 2^shift; when div_by_zero is set, mantissa and shift are
invalid.

THE LATENCY OF THIS MODULE IS 21 CYCLES = 18 (generate_ray) + 3 (ray_dir_inverse)
*/
module path_tracer_top
    import data_structs_pkg::*;
(
    input wire clk,
    input wire rst,

    // upstream interface
    // data
    input  wire [9:0]  us_pixel_x_i,            // [0, 799]
    input  wire [9:0]  us_pixel_y_i,            // [0, 599]
    input  wire [11:0] us_pixel_sample_idx_i,   // [0, 4095]
    // control
    input  wire        us_vld_i,
    output wire        us_stall_o,

    // downstream interface
    // data
    output ray_t        ds_ray_o,                   // origin + unit direction (SQ1.16), aligned with the inverse below

    output wire [16:0]  ds_inv_dir_mantissa_x_o,    // Q1.16
    output wire [16:0]  ds_inv_dir_mantissa_y_o,    // Q1.16
    output wire [16:0]  ds_inv_dir_mantissa_z_o,    // Q1.16

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
    // generate_ray -> ray_dir_inverse handshake
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ray_t gen_ray;          // generated ray, valid with gen_ray_vld
    logic gen_ray_vld;
    logic gen_ray_stall;    // stall from ray_dir_inverse back to generate_ray

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // generate_ray: LATENCY = 18 CYCLES
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    generate_ray u_generate_ray (
        .clk(clk),
        .rst(rst),

        // upstream interface
        .us_pixel_x_i(us_pixel_x_i),
        .us_pixel_y_i(us_pixel_y_i),
        .us_pixel_sample_idx_i(us_pixel_sample_idx_i),
        .us_vld_i(us_vld_i),
        .us_stall_o(us_stall_o),

        // downstream interface
        .ds_ray_o(gen_ray),
        .ds_vld_o(gen_ray_vld),
        .ds_stall_i(gen_ray_stall)
    );

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // ray_dir_inverse: LATENCY = 3 CYCLES
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    ray_dir_inverse u_ray_dir_inverse (
        .clk(clk),
        .rst(rst),

        // upstream interface
        .us_unit_ray_dir_i(gen_ray.dir),
        .us_vld_i(gen_ray_vld),
        .us_stall_o(gen_ray_stall),

        // downstream interface
        .ds_inv_dir_mantissa_x_o(ds_inv_dir_mantissa_x_o),
        .ds_inv_dir_mantissa_y_o(ds_inv_dir_mantissa_y_o),
        .ds_inv_dir_mantissa_z_o(ds_inv_dir_mantissa_z_o),

        .ds_inv_dir_sign_x_o(ds_inv_dir_sign_x_o),
        .ds_inv_dir_sign_y_o(ds_inv_dir_sign_y_o),
        .ds_inv_dir_sign_z_o(ds_inv_dir_sign_z_o),

        .ds_inv_dir_div_by_zero_x_o(ds_inv_dir_div_by_zero_x_o),
        .ds_inv_dir_div_by_zero_y_o(ds_inv_dir_div_by_zero_y_o),
        .ds_inv_dir_div_by_zero_z_o(ds_inv_dir_div_by_zero_z_o),

        .ds_inv_dir_shift_x_o(ds_inv_dir_shift_x_o),
        .ds_inv_dir_shift_y_o(ds_inv_dir_shift_y_o),
        .ds_inv_dir_shift_z_o(ds_inv_dir_shift_z_o),

        .ds_vld_o(ds_vld_o),
        .ds_stall_i(ds_stall_i)
    );

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // ray alignment pipe: delays the generated ray by ray_dir_inverse's latency so the ray and its inverse
    // direction leave the top on the same cycle (the bbox test needs the origin alongside the inverse).
    // TODO: move this into ray_dir_inverse as a USER sideband (like tea_hash) so the delay always matches its
    //       latency by construction instead of by this constant.
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    localparam int INV_DIR_LATENCY = 3;     // must equal ray_dir_inverse's latency

    // index 0 is the generate_ray output, index i is the ray after i register stages
    ray_t ray_pipe [INV_DIR_LATENCY+1];

    assign ray_pipe[0] = gen_ray;

    for (genvar i = 1; i <= INV_DIR_LATENCY; i++) begin : g_ray_pipe
        // data only, no reset; same enable as ray_dir_inverse's registers
        `FFLNR(ray_pipe[i], ray_pipe[i-1], ~ds_stall_i, clk)
    end

    assign ds_ray_o = ray_pipe[INV_DIR_LATENCY];

endmodule