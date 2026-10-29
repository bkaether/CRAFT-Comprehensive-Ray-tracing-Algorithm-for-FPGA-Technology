`timescale 1ns/1ps

interface generate_ray_intf 
    import data_structs_pkg::*;
(
    input logic clk
);

    // Signal names mirror the generate_ray port names exactly, so the
    // TB module connections can be checked by eye. The _i / _o suffixes
    // are from the DUT's point of view, not the testbench's: the driver
    // drives *_i signals (DUT inputs) and samples *_o signals (DUT outputs),
    // so clocking block directions appear reversed relative to the suffixes.

    logic rst;

    // upstream interface
    // data
    logic [9:0] us_pixel_x_i;
    logic [9:0] us_pixel_y_i;
    // control
    logic us_vld_i;
    logic us_stall_o;

    // downstream interface
    // data
    ray ds_ray_o;
    // control
    logic ds_vld_o;
    logic ds_stall_i;

    // probes to internal signals for testbench visibility
    logic [15:0] prng_offset_x;
    logic [15:0] prng_offset_y;

    // Driver view: drives DUT inputs just after the edge, samples DUT outputs just before it.
    clocking mcb @(posedge clk);

        output rst;
        output us_pixel_x_i;
        output us_pixel_y_i;
        output us_vld_i;

        input ds_ray_o;
        input ds_vld_o;
        input us_stall_o;

    endclocking

    // Passive view: samples everything, drives nothing.
    clocking pcb @(posedge clk);

        input rst;
        input ds_stall_i;
        input us_pixel_x_i;
        input us_pixel_y_i;
        input us_vld_i;

        input ds_ray_o;
        input ds_vld_o;
        input us_stall_o;

        input prng_offset_x;
        input prng_offset_y;

    endclocking

    // Each role sees only its own clocking block.
    modport drv (clocking mcb);
    modport mon (clocking pcb);

endinterface