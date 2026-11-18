class ray_bbox_intersect_driver;

    virtual ray_bbox_intersect_intf.drv vif;

    function new(virtual ray_bbox_intersect_intf.drv vif);
        this.vif = vif;
    endfunction

    task drive_reset();

        @(vif.mcb);

        vif.mcb.us_vld_i <= 1'b0;
        vif.mcb.rst <= 1'b1;

        repeat (2) @(vif.mcb);

        vif.mcb.rst <= 1'b0;

        @(vif.mcb);

    endtask

    task drive_trans(ray_bbox_intersect_input_trans trans);
    
        // set DUT inputs to values from the transaction object
        vif.mcb.us_ray_orig_i              <= trans.ray_orig;

        vif.mcb.us_inv_dir_mantissa_x_i    <= trans.inv_dir_x;
        vif.mcb.us_inv_dir_mantissa_y_i    <= trans.inv_dir_x;
        vif.mcb.us_inv_dir_mantissa_z_i    <= trans.inv_dir_x;

        vif.mcb.us_inv_dir_sign_x_i        <= trans.sign_x;
        vif.mcb.us_inv_dir_sign_y_i        <= trans.sign_y;
        vif.mcb.us_inv_dir_sign_z_i        <= trans.sign_z;

        vif.mcb.us_inv_dir_div_by_zero_x_i <= trans.div_by_zero_x;
        vif.mcb.us_inv_dir_div_by_zero_y_i <= trans.div_by_zero_y;
        vif.mcb.us_inv_dir_div_by_zero_z_i <= trans.div_by_zero_z;

        vif.mcb.us_inv_dir_shift_x_i       <= trans.shift_x;
        vif.mcb.us_inv_dir_shift_y_i       <= trans.shift_y;
        vif.mcb.us_inv_dir_shift_z_i       <= trans.shift_z;

        vif.mcb.us_box_i                   <= trans.box;

        vif.mcb.us_vld_i                   <= trans.vld;

        @(vif.mcb);

        while (trans.vld && vif.mcb.us_stall_o) begin
            // hold data and vld until dut stall is released, behaving as the upstream block would
            @(vif.mcb);
        end

    endtask

    task stop_trans();
        vif.mcb.us_vld_i <= 1'b0;

        @(vif.mcb);
    endtask

endclass