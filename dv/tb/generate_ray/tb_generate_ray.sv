`timescale 1ns/1ps

module tb_generate_ray();

    import tb_generate_ray_pkg::*;
    import backpressure_pkg::*;

    // top level testbench knobs
    localparam int PIXEL_WIDTH = 800;
    localparam int PIXEL_HEIGHT = 600;
    localparam real FOV_DEGREES = 70.0;
    localparam real ERROR_THRESHOLD = 0.001;

    // mailboxes for communication between testbench components
    input_mbx_t input_mbx;
    output_mbx_t output_mbx;

    // instantiate testbench components
    generate_ray_driver drv;
    generate_ray_monitor mon;
    generate_ray_scoreboard sb;

    backpressure_driver backpressure_drv;

    // clk signal controlled by testbench, 125 MHz clock (8 ns period)
    logic clk;

    always #4 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    // instantiate dut interface
    generate_ray_intf u_generate_ray_intf(.clk(clk));

    // instantiate backpressure interface
    backpressure_intf u_backpressure_intf(.clk(clk));

    generate_ray u_generate_ray (
        .clk(clk),
        .rst(u_generate_ray_intf.rst),

        // upstream interface
        // data
        .us_pixel_x_i(u_generate_ray_intf.us_pixel_x_i),
        .us_pixel_y_i(u_generate_ray_intf.us_pixel_y_i),
        // control
        .us_vld_i(u_generate_ray_intf.us_vld_i),
        .us_stall_o(u_generate_ray_intf.us_stall_o),

        // downstream interface
        // data
        .ds_ray_o(u_generate_ray_intf.ds_ray_o),
        // control
        .ds_vld_o(u_generate_ray_intf.ds_vld_o),
        .ds_stall_i(u_backpressure_intf.stall)
    );

    // connect internal prng interface probes
    assign u_generate_ray_intf.prng_offset_x = u_generate_ray.offset_x;
    assign u_generate_ray_intf.prng_offset_y = u_generate_ray.offset_y;

    // connect gen ray stall in
    assign u_generate_ray_intf.ds_stall_i = u_backpressure_intf.stall;

    task automatic build();
        // mailboxes must be built before the monitor and scoreboard are constructed, so they can be passed in as constructor arguments
        input_mbx = new();
        output_mbx = new();

        drv = new(u_generate_ray_intf.drv);
        mon = new(u_generate_ray_intf.mon, input_mbx, output_mbx);
        sb = new(input_mbx, output_mbx, FOV_DEGREES, PIXEL_WIDTH, PIXEL_HEIGHT, ERROR_THRESHOLD);

        backpressure_drv = new(u_backpressure_intf.drv);
    endtask

    task automatic test_dut(int num_valid_pixels, bit send_valid_pixels_only = 1'b0);

        int n = 0;
        generate_ray_input_trans trans = new();

        while (n < num_valid_pixels) begin

            // only send transactions with vld = 1 if specified
            if (!trans.randomize() with { send_valid_pixels_only -> trans.vld == 1'b1; }) begin
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

    task drain();

        // turn off backpressure
        backpressure_drv.mode = NONE;

        // make sure us_vld_i is deasserted
        drv.stop_trans();

        // wait for a few cycles to allow for lingering stalls to deassert and the pipeline to drain
        repeat (20) @(u_generate_ray_intf.mcb);

    endtask

    initial begin

        build();

        // kick off forever tasks in the monitor and scoreboard, and backpressure task (set to mode NONE from constructor)
        fork
            mon.run();
            sb.run();
            backpressure_drv.run();
        join_none

        // perform reset sequence
        drv.drive_reset();

        // configure backpressure settings
        backpressure_drv.mode = RAND;

        // run the test with RAND backpressure
        test_dut(200);
            
        // change backpressure setting
        backpressure_drv.mode = BURST;

        // run the test with random burst stalls
        test_dut(200);

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