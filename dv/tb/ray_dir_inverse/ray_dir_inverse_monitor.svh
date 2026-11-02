class ray_dir_inverse_monitor;

    virtual ray_dir_inverse_intf.mon vif;

    input_mbx_t  input_mbx;
    output_mbx_t output_mbx;

    function new(virtual ray_dir_inverse_intf.mon vif, input_mbx_t  input_mbx, output_mbx_t output_mbx);

        this.vif = vif;

        this.input_mbx = input_mbx;
        this.output_mbx = output_mbx;

    endfunction

    task watch_inputs();

        forever begin
            @(vif.pcb);

            if (vif.pcb.us_vld_i && !vif.pcb.us_stall_o && !vif.pcb.rst) begin
                unit_vec3_t observed_input;

                observed_input = vif.pcb.us_unit_ray_dir_i;

                input_mbx.put(observed_input);
            end
        end

    endtask

    task watch_outputs();

        forever begin
            @(vif.pcb);

            if (vif.pcb.ds_vld_o && !vif.pcb.ds_stall_i) begin
                ray_dir_inverse_observed_output_t observed_output;

                observed_output.mantissa_x = vif.pcb.ds_inv_dir_mantissa_x_o;
                observed_output.mantissa_y = vif.pcb.ds_inv_dir_mantissa_y_o;
                observed_output.mantissa_z = vif.pcb.ds_inv_dir_mantissa_z_o;

                observed_output.sign_x = vif.pcb.ds_inv_dir_sign_x_o;
                observed_output.sign_y = vif.pcb.ds_inv_dir_sign_y_o;
                observed_output.sign_z = vif.pcb.ds_inv_dir_sign_z_o;

                observed_output.div_by_zero_x = vif.pcb.ds_inv_dir_div_by_zero_x_o;
                observed_output.div_by_zero_y = vif.pcb.ds_inv_dir_div_by_zero_y_o;
                observed_output.div_by_zero_z = vif.pcb.ds_inv_dir_div_by_zero_z_o;

                observed_output.shift_x = vif.pcb.ds_inv_dir_shift_x_o;
                observed_output.shift_y = vif.pcb.ds_inv_dir_shift_y_o;
                observed_output.shift_z = vif.pcb.ds_inv_dir_shift_z_o;

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