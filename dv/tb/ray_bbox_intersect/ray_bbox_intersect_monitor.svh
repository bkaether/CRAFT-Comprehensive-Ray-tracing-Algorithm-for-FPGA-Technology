class ray_bbox_intersect_monitor;

    virtual ray_bbox_intersect_intf.mon vif;

    input_mbx_t  input_mbx;
    output_mbx_t output_mbx;

    function new(virtual ray_bbox_intersect_intf.mon vif, input_mbx_t  input_mbx, output_mbx_t output_mbx);

        this.vif = vif;

        this.input_mbx = input_mbx;
        this.output_mbx = output_mbx;

    endfunction

    task watch_inputs();

        forever begin
            @(vif.pcb);

            if (vif.pcb.us_vld_i && !vif.pcb.us_stall_o && !vif.pcb.rst) begin
                ray_bbox_intersect_observed_input observed_input;

                observed_input.ray_orig  = vif.pcb.us_ray_orig_i;

                observed_input.inv_dir_x = vif.pcb.us_inv_dir_mantissa_x_i;
                observed_input.inv_dir_y = vif.pcb.us_inv_dir_mantissa_y_i;
                observed_input.inv_dir_z = vif.pcb.us_inv_dir_mantissa_z_i;

                observed_input.sign_x    = vif.pcb.us_inv_dir_sign_x_i;
                observed_input.sign_y    = vif.pcb.us_inv_dir_sign_y_i;
                observed_input.sign_z    = vif.pcb.us_inv_dir_sign_z_i;

                observed_input.div_by_zero_x = vif.pcb.us_inv_dir_div_by_zero_x_i;
                observed_input.div_by_zero_y = vif.pcb.us_inv_dir_div_by_zero_y_i;
                observed_input.div_by_zero_z = vif.pcb.us_inv_dir_div_by_zero_z_i;

                observed_input.shift_x = vif.pcb.us_inv_dir_shift_x_i;
                observed_input.shift_y = vif.pcb.us_inv_dir_shift_y_i;
                observed_input.shift_z = vif.pcb.us_inv_dir_shift_z_i;

                input_mbx.put(observed_input);
            end
        end

    endtask

    task watch_outputs();

        forever begin
            @(vif.pcb);

            if (vif.pcb.ds_vld_o && !vif.pcb.ds_stall_i) begin
                ray_bbox_intersect_observed_output_t observed_output;

                // TODO

                output_mbx.put(observed_output);

            end
        end

    endtask

    task run();

        fork
            watch_inputs();
            watch_outputs();
        join_none

    endtask

endclass