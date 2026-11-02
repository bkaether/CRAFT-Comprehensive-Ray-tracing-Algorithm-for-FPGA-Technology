`timescale  1ns/1ps

module tb_ray_dir_inverse();

    import data_structs_pkg::*;
    import tb_pkg::*;
    import tb_ray_dir_inverse_pkg::*;
    import backpressure_pkg::*;

    // mailboxes for communication between testbench components
    input_mbx_t input_mbx;
    output_mbx_t output_mbx; 

    ray_dir_inverse_monitor mon;
    ray_dir_inverse_driver  drv;
    ray_dir_inverse_scoreboard sb;

    backpressure_driver backpressure_drv;

    logic clk;

    always #4 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    ray_dir_inverse_intf u_ray_dir_inverse_intf(.clk(clk));

    backpressure_intf u_backpressure_intf(.clk(clk));

    ray_dir_inverse u_ray_dir_inverse (
        .clk(clk),
        .rst(u_ray_dir_inverse_intf.rst),

        // upstream interface
        // data
        .us_unit_ray_dir_i(u_ray_dir_inverse_intf.us_unit_ray_dir_i),
        // control
        .us_vld_i(u_ray_dir_inverse_intf.us_vld_i),
        .us_stall_o(u_ray_dir_inverse_intf.us_stall_o),

        // downstream interface
        // data
        .ds_inv_dir_mantissa_x_o(u_ray_dir_inverse_intf.ds_inv_dir_mantissa_x_o),
        .ds_inv_dir_mantissa_y_o(u_ray_dir_inverse_intf.ds_inv_dir_mantissa_y_o),
        .ds_inv_dir_mantissa_z_o(u_ray_dir_inverse_intf.ds_inv_dir_mantissa_z_o),

        .ds_inv_dir_sign_x_o(u_ray_dir_inverse_intf.ds_inv_dir_sign_x_o),
        .ds_inv_dir_sign_y_o(u_ray_dir_inverse_intf.ds_inv_dir_sign_y_o),
        .ds_inv_dir_sign_z_o(u_ray_dir_inverse_intf.ds_inv_dir_sign_z_o),

        .ds_inv_dir_div_by_zero_x_o(u_ray_dir_inverse_intf.ds_inv_dir_div_by_zero_x_o),
        .ds_inv_dir_div_by_zero_y_o(u_ray_dir_inverse_intf.ds_inv_dir_div_by_zero_y_o),
        .ds_inv_dir_div_by_zero_z_o(u_ray_dir_inverse_intf.ds_inv_dir_div_by_zero_z_o),

        .ds_inv_dir_shift_x_o(u_ray_dir_inverse_intf.ds_inv_dir_shift_x_o),
        .ds_inv_dir_shift_y_o(u_ray_dir_inverse_intf.ds_inv_dir_shift_y_o),
        .ds_inv_dir_shift_z_o(u_ray_dir_inverse_intf.ds_inv_dir_shift_z_o),
        // control
        .ds_vld_o(u_ray_dir_inverse_intf.ds_vld_o),
        .ds_stall_i(u_backpressure_intf.stall)
    );

    assign u_ray_dir_inverse_intf.ds_stall_i = u_backpressure_intf.stall;

    task automatic build();

        input_mbx = new();
        output_mbx = new();

        drv = new(u_ray_dir_inverse_intf.drv);
        mon = new(u_ray_dir_inverse_intf.mon, input_mbx, output_mbx);
        sb = new(input_mbx, output_mbx);

        backpressure_drv = new(u_backpressure_intf.drv);

    endtask

    task automatic test_dut(input int num_valid_rays, input bit send_valid_rays_only = 1'b0);

        int n = 0;
        ray_dir_inverse_input_trans trans = new();

        while (n < num_valid_rays) begin
            // only send transactions with vld = 1 if specified
            if (!trans.randomize() with { send_valid_rays_only -> trans.vld == 1'b1; }) begin
                $fatal(1, "Failed to randomize input transaction");
            end

            // apply input transaction to DUT
            drv.drive_trans(trans);

            // only count transactions with vld = 1 towards the total number of transactions
            if (trans.vld) begin
                n++;
            end
        end

    endtask

    task automatic drain(input int cycles = 20);

        // turn off backpressure
        backpressure_drv.mode = NONE;

        // make sure us_vld_i is deasserted
        drv.stop_trans();

        // wait for a few cycles to allow for lingering stalls to deassert and the pipeline to drain
        repeat (cycles) @(u_ray_dir_inverse_intf.mcb);

    endtask

    initial begin
        build();

        fork
            mon.run();
            sb.run();
            backpressure_drv.run();
        join_none

        drv.drive_reset();

         // run the test with RAND backpressure
        test_dut(10000);
            
        // change backpressure setting
        backpressure_drv.mode = BURST;

        // run the test with random burst stalls
        test_dut(10000);

        // drain the pipeline by deasserting stall and waiting a few cycles
        drain();

        sb.report_results();

        if (sb.err_count > 0) begin
            $error("Test failed with %0d errors", sb.err_count);
        end else begin
            $display("Test Passed!");
        end

        $finish();

    end

endmodule