`timescale 1ns/1ps

interface generate_ray_intf 
    import data_structs_pkg::*;
(
    input logic clk
);

    // module inputs
    logic rst_n;
    logic stall_in;
    logic [9:0] pixel_x;
    logic [9:0] pixel_y;
    logic pixel_valid;

    // module outputs
    ray generated_ray;
    logic ray_valid;
    logic stall_out;

    // probes to internal signals for testbench visibility
    logic [15:0] prng_offset_x;
    logic [15:0] prng_offset_y;

    // Driver view: drives DUT inputs just after the edge,
    // samples DUT outputs just before it.
    clocking mcb @(posedge clk);

        output rst_n;
        output pixel_x;
        output pixel_y;
        output pixel_valid;

        input generated_ray;
        input ray_valid;
        input stall_out;

        input prng_offset_x;
        input prng_offset_y;

    endclocking

    // Passive view: samples everything, drives nothing.
    clocking pcb @(posedge clk);

        input rst_n;
        input stall_in;
        input pixel_x;
        input pixel_y;
        input pixel_valid;

        input generated_ray;
        input ray_valid;
        input stall_out;

        input prng_offset_x;
        input prng_offset_y;

    endclocking

    // Each role sees only its own clocking block.
    modport drv (clocking mcb);
    modport mon (clocking pcb);

endinterface