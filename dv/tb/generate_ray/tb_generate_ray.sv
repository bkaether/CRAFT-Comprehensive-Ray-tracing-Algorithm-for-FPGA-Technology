`timescale 1ns/1ps

module tb_generate_ray();

    import tb_generate_ray_pkg::*;

    // top level testbench knobs
    localparam int PIXEL_WIDTH = 800;
    localparam int PIXEL_HEIGHT = 600;
    localparam real FOV_DEGREES = 83;
    localparam real ERROR_THRESHOLD = 0.01;

    // mailboxes for communication between testbench components
    input_mbx_t input_mbx;
    output_mbx_t output_mbx;

    // instantiate testbench components
    generate_ray_driver drv;
    generate_ray_monitor mon;
    generate_ray_scoreboard sb;

    // clk signal controlled by testbench, 125 MHz clock (8 ns period)
    logic clk;

    always #4 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    // instantiate interface
    generate_ray_intf u_generate_ray_if(.clk(clk));

    generate_ray u_generate_ray (
        .clk(clk),
        .rst_n(u_generate_ray_if.rst_n),
        .stall(u_generate_ray_if.stall),
        .pixel_x(u_generate_ray_if.pixel_x),
        .pixel_y(u_generate_ray_if.pixel_y),
        .pixel_valid(u_generate_ray_if.pixel_valid),

        .generated_ray(u_generate_ray_if.generated_ray),
        .ray_valid(u_generate_ray_if.ray_valid)
    );

    // connect internal prng interface probes
    assign u_generate_ray_if.prng_offset_x = u_generate_ray.offset_x;
    assign u_generate_ray_if.prng_offset_y = u_generate_ray.offset_y;

    task automatic build();
        // mailboxes must be built before the monitor and scoreboard are constructed, so they can be passed in as constructor arguments
        input_mbx = new();
        output_mbx = new();

        drv = new(u_generate_ray_if.drv);
        mon = new(u_generate_ray_if.mon, input_mbx, output_mbx);
        sb = new(input_mbx, output_mbx, FOV_DEGREES, PIXEL_WIDTH, PIXEL_HEIGHT, ERROR_THRESHOLD);
    endtask

    task automatic test_dut(int num_valid_pixels, bit send_valid_pixels_only = 1'b0);

        int n = 0;
        generate_ray_input_trans trans = new();

        while (n < num_valid_pixels) begin

            // only send transactions with pixel_valid = 1 if specified
            if (send_valid_pixels_only) begin
                trans.randomize() with { trans.pixel_valid == 1'b1; };
            end else begin
                trans.randomize();
            end

            // apply input transaction to DUT
            drv.drive_trans(trans);

            // only count transactions with pixel_valid = 1 towards the total number of transactions
            if (trans.pixel_valid) begin
                n++;
            end
        end

    endtask

    initial begin

        build();

        // kick off forever tasks in the monitor and scoreboard
        fork
            mon.run();
            sb.run();
        join_none

        // perform reset sequence
        drv.drive_reset();

        // run the test for a specified number of transactions
        test_dut(200, 1'b1);

        // drain the pipeline by deasserting stall and waiting a few cycles
        drv.drain();

        sb.report_results();

        if (sb.err_count > 0) begin
            $error("Test Failed!", sb.err_count);
        end else begin
            $display("Test Passed!");
        end

        $finish();
    end


endmodule