package tb_generate_ray_pkg;

    import data_structs_pkg::*;
    import tb_pkg::*;

    typedef struct packed {
        bit [9:0]  pixel_x;
        bit [9:0]  pixel_y;
        bit [11:0] pixel_sample_idx;
    } generate_ray_observed_input;

    typedef mailbox #(generate_ray_observed_input) input_mbx_t;
    typedef mailbox #(ray) output_mbx_t;

    `include "generate_ray_input_trans.svh"
    `include "generate_ray_driver.svh"
    `include "generate_ray_monitor.svh"
    `include "generate_ray_scoreboard.svh"

endpackage