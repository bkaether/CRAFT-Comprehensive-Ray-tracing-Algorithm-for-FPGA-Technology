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
        vif.mcb.stall <= 1'b0;
        vif.mcb.pixel_valid <= 1'b0;
        vif.mcb.rst_n <= 1'b0;

        // hold reset for two cycles
        repeat (2) @(vif.mcb);

        // deassert reset
        vif.mcb.rst_n <= 1'b1;

        // end on a clocking edge so that the next transaction can be driven with proper timing
        @(vif.mcb);

    endtask

    task drive_trans(generate_ray_input_trans trans);
    
        // set DUT inputs to values from the transaction object
        vif.mcb.pixel_x <= trans.pixel_x;
        vif.mcb.pixel_y <= trans.pixel_y;
        vif.mcb.pixel_valid <= trans.pixel_valid;
        vif.mcb.stall <= trans.stall;

        // clocking event so flops in the DUT can sample the inputs
        @(vif.mcb);

    endtask

    task drain();

        // deassert stall so that pipeline can drain
        vif.mcb.stall <= 1'b0;

        // make sure no more pixels are valid during the drain time
        vif.mcb.pixel_valid <= 1'b0;

        // wait for a few cycles to allow the pipeline to drain
        repeat (10) @(vif.mcb);

    endtask

endclass