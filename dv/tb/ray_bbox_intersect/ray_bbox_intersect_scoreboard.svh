class ray_bbox_intersect_scoreboard;

    input_mbx_t  input_mbx;
    output_mbx_t output_mbx;

    int err_count;
    int successful_checks;
    int num_hits;

    function new(input_mbx_t input_mbx, output_mbx_t output mbx);
        this.input_mbx = input_mbx;
        this.output_mbx = output_mbx;

        err_count = 0;
        successful_checks = 0;
        num_hits = 0;
    endfunction

    function compute_expected(input  ray_bbox_intersect_observed_input  observed_input,
                              output bit hit, output real distance);

        real orig_x, orig_y, orig_z;
        real inv_dir_x, inv_dir_y, inv_dir_z;
        real shift_x, shift_y, shift_z;

        real box_min_x, box_min_y, box_min_z;
        real box_max_x, box_max_y, box_max_z;

        real tx0, ty0, tz0;
        real tx1, ty1, tz1;

        orig_x = fxpt_to_real(observed_input.ray_orig.x, 16);
        orig_y = fxpt_to_real(observed_input.ray_orig.y, 16);
        orig_z = fxpt_to_real(observed_input.ray_orig.z, 16);

        inv_dir_x = fxpt_to_real(observed_input.inv_dir_x, 16);
        inv_dir_y = fxpt_to_real(observed_input.inv_dir_y, 16);
        inv_dir_z = fxpt_to_real(observed_input.inv_dir_z, 16);

        shift_x = real'()

    endfunction


endclass