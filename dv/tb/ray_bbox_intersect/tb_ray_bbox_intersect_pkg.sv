package ray_bbox_intersect_pkg;

    import data_structs_pkg::*;
    import tb_pkg::*;

    typedef struct {

        point_t      ray_orig;

        logic [16:0] inv_dir_x;
        logic [16:0] inv_dir_y;
        logic [16:0] inv_dir_z;

        logic sign_x;
        logic sign_y;
        logic sign_z;

        logic div_by_zero_x;
        logic div_by_zero_y;
        logic div_by_zero_z;

        logic [4:0] shift_x;
        logic [4:0] shift_y;
        logic [4:0] shift_z;

        bbox_t box;

    } ray_bbox_intersect_observed_input;

    typedef struct {

        logic                ds_hit_o,
        logic signed [29:0]  ds_bbox_distance_o,  // SQ13.16

    } ray_bbox_intersect_observed_output;

    typedef mailbox #(ray_bbox_intersect_observed_input)  input_mbx_t;
    typedef mailbox #(ray_bbox_intersect_observed_output) output_mbx_t;

    `include "ray_bbox_intersect_input_trans.svh"
    `include "ray_bbox_intersect_driver.svh"
    `include "ray_bbox_intersect_monitor.svh"
    `include "ray_bbox_intersect_scoreboard.svh"
    
endpackage