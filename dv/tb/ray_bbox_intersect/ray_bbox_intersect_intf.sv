interface ray_bbox_intersect_intf (
    input wire clk
);

    logic rst;

    // upstream interface
    // data
    point_t us_ray_orig_i;

    logic [16:0] us_inv_dir_mantissa_x_i;
    logic [16:0] us_inv_dir_mantissa_y_i;
    logic [16:0] us_inv_dir_mantissa_z_i;

    logic us_inv_dir_sign_x_i;
    logic us_inv_dir_sign_y_i;
    logic us_inv_dir_sign_z_i;

    logic us_inv_dir_div_by_zero_x_i;
    logic us_inv_dir_div_by_zero_y_i;
    logic us_inv_dir_div_by_zero_z_i;

    logic [4:0] us_inv_dir_shift_x_i;
    logic [4:0] us_inv_dir_shift_y_i;
    logic [4:0] us_inv_dir_shift_z_i;

    bbox_t us_box_i;
    // control
    logic us_vld_i;
    logic us_stall_o;

    // downstream interface
    // data
    logic                ds_hit_o;
    logic signed [29:0]  ds_bbox_distance_o;  // SQ13.16
    // control
    logic                ds_vld_o;
    logic                ds_stall_i;

    clocking mcb @(posedge clk);

        output rst;

        output us_ray_orig_i;

        output us_inv_dir_mantissa_x_i;
        output us_inv_dir_mantissa_y_i;
        output us_inv_dir_mantissa_z_i;

        output us_inv_dir_sign_x_i;
        output us_inv_dir_sign_y_i;
        output us_inv_dir_sign_z_i;

        output us_inv_dir_div_by_zero_x_i;
        output us_inv_dir_div_by_zero_y_i;
        output us_inv_dir_div_by_zero_z_i;

        output us_inv_dir_shift_x_i;
        output us_inv_dir_shift_y_i;
        output us_inv_dir_shift_z_i;

        output us_box_i;

        output us_vld_i;


        input  us_stall_o;


    endclocking

    clocking pcb(posedge clk);

        input rst;

        // upstream interface
        // data
        point_t us_ray_orig_i;

        input us_inv_dir_mantissa_x_i;
        input us_inv_dir_mantissa_y_i;
        input us_inv_dir_mantissa_z_i;

        input us_inv_dir_sign_x_i;
        input us_inv_dir_sign_y_i;
        input us_inv_dir_sign_z_i;

        input us_inv_dir_div_by_zero_x_i;
        input us_inv_dir_div_by_zero_y_i;
        input us_inv_dir_div_by_zero_z_i;

        input us_inv_dir_shift_x_i;
        input us_inv_dir_shift_y_i;
        input us_inv_dir_shift_z_i;

        bbox_t us_box_i;
        // control
        input us_vld_i;
        input us_stall_o;

        // downstream interface
        // data
        input   ds_hit_o;
        input   ds_bbox_distance_o;  // SQ13.16
        // control
        input   ds_vld_o;
        input   ds_stall_i;

    endclocking

    modport drv(clocking mcb);
    modport mon(clocking pcb);

endinterface