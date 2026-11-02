package tb_ray_dir_inverse_pkg;

    import data_structs_pkg::*;
    import tb_pkg::*;

    typedef struct packed {

        logic [16:0]  mantissa_x;   // Q1.16 per x/y/z component
        logic [16:0]  mantissa_y;   // Q1.16 per x/y/z component
        logic [16:0]  mantissa_z;   // Q1.16 per x/y/z component

        logic         sign_x;
        logic         sign_y;
        logic         sign_z;

        logic         div_by_zero_x;
        logic         div_by_zero_y;
        logic         div_by_zero_z;

        logic [4:0]   shift_x;
        logic [4:0]   shift_y;
        logic [4:0]   shift_z;

    } ray_dir_inverse_observed_output_t;

    typedef mailbox #(unit_vec3_t) input_mbx_t;
    typedef mailbox #(ray_dir_inverse_observed_output_t) output_mbx_t;

    `include "ray_dir_inverse_input_trans.svh"
    `include "ray_dir_inverse_driver.svh"
    `include "ray_dir_inverse_monitor.svh"
    `include "ray_dir_inverse_scoreboard.svh"

endpackage