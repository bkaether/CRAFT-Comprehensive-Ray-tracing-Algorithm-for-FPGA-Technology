interface ray_dir_inverse_intf
    import data_structs_pkg::*;
(
    input wire clk
);

    logic rst;
    
    // upstream interface
    // data
    unit_vec3_t us_unit_ray_dir_i;    // SQ1.16 per x/y/z component
    // control
    logic us_vld_i;
    logic us_stall_o;

    // downstream interface
    // data
    logic [16:0]  ds_inv_dir_mantissa_x_o;   // Q1.16 per x/y/z component
    logic [16:0]  ds_inv_dir_mantissa_y_o;   // Q1.16 per x/y/z component
    logic [16:0]  ds_inv_dir_mantissa_z_o;   // Q1.16 per x/y/z component

    logic         ds_inv_dir_sign_x_o;
    logic         ds_inv_dir_sign_y_o;
    logic         ds_inv_dir_sign_z_o;

    logic         ds_inv_dir_div_by_zero_x_o;
    logic         ds_inv_dir_div_by_zero_y_o;
    logic         ds_inv_dir_div_by_zero_z_o;

    logic [4:0]   ds_inv_dir_shift_x_o;
    logic [4:0]   ds_inv_dir_shift_y_o;
    logic [4:0]   ds_inv_dir_shift_z_o;

    // control
    logic         ds_vld_o;
    logic         ds_stall_i;

    clocking mcb @(posedge clk);

        output rst;

        output us_unit_ray_dir_i;
        output us_vld_i;

        input us_stall_o;

    endclocking

    clocking pcb @(posedge clk);

        input rst;

        // upstream interface
        // data
        input us_unit_ray_dir_i;    // SQ1.16 per x/y/z component
        // control
        input us_vld_i;
        input us_stall_o;

        // downstream interface
        // data
        input ds_inv_dir_mantissa_x_o;   // Q1.16 per x/y/z component
        input ds_inv_dir_mantissa_y_o;   // Q1.16 per x/y/z component
        input ds_inv_dir_mantissa_z_o;   // Q1.16 per x/y/z component

        input ds_inv_dir_sign_x_o;
        input ds_inv_dir_sign_y_o;
        input ds_inv_dir_sign_z_o;

        input ds_inv_dir_div_by_zero_x_o;
        input ds_inv_dir_div_by_zero_y_o;
        input ds_inv_dir_div_by_zero_z_o;

        input ds_inv_dir_shift_x_o;
        input ds_inv_dir_shift_y_o;
        input ds_inv_dir_shift_z_o;
        // control
        input ds_vld_o;
        input ds_stall_i;

    endclocking

    modport drv(clocking mcb);
    modport mon(clocking pcb);


endinterface