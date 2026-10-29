class generate_ray_driver;

    // handle to the interface drv modport for access to master clocking block (mcb)
    virtual generate_ray_intf.drv vif;

    // allow testbench to pass in the true interface handle when creating the driver.
    // interfaces in SystemVerilog must be virtual inside classes
    function new(virtual generate_ray_intf.drv vif);
        this.vif = vif;
    endfunction

    task drive_reset();

        // align to a clocking edge for proper driving of initial signals with a clocking block
        @(vif.mcb);

        // set control inputs to known values (data inputs can be left unknown) and assert reset
        vif.mcb.us_vld_i <= 1'b0;
        vif.mcb.rst <= 1'b1;

        // hold reset for two cycles
        repeat (2) @(vif.mcb);

        // deassert reset
        vif.mcb.rst <= 1'b0;

        // end on a clocking edge so that the next transaction can be driven with proper timing
        @(vif.mcb);

    endtask

    task drive_trans(generate_ray_input_trans trans);
    
        // set DUT inputs to values from the transaction object
        vif.mcb.us_pixel_x_i <= trans.pixel_x;
        vif.mcb.us_pixel_y_i <= trans.pixel_y;
        vif.mcb.us_vld_i <= trans.vld;

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