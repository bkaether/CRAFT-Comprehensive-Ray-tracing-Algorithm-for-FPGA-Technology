`timescale 1ns/1ps

`include "../data_macros.sv"

import tb_pkg::*;

module generate_ray_tb();

    // testbench knobs
    localparam int NUM_TEST_PIXELS = 50;
    localparam int PIXEL_WIDTH = 800;
    localparam int PIXEL_HEIGHT = 600;
    localparam real FOV_DEGREES = 70.0;
    localparam real ERROR_THRESHOLD = 0.01;

    // error counter
    int num_errors = 0;

    // test vector inputs
    int test_pixels_x[NUM_TEST_PIXELS];
    int test_pixels_y[NUM_TEST_PIXELS];

    // expected output arrays
    real expected_dir_x[NUM_TEST_PIXELS];
    real expected_dir_y[NUM_TEST_PIXELS];

    // actual DUT output array
    ray actual_rays[NUM_TEST_PIXELS];

    // random values used by the hardware for each calculation in Q0.16 fixed point format
    bit [15:0] prng_x_fxpt[NUM_TEST_PIXELS];
    bit [15:0] prng_y_fxpt[NUM_TEST_PIXELS];
    // hardware generated random values converted to real decimal format for use in expected output calculation
    real prng_x[NUM_TEST_PIXELS];
    real prng_y[NUM_TEST_PIXELS];

    // DUT signals
    // inputs
    reg clk;
    reg rst_n;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    reg stall;

    // outputs
    ray generated_ray;

    always #4 clk = ~clk;

    generate_ray DUT (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .stall(stall),

        .generated_ray(generated_ray)
    );

    task automatic test_dut();
        for (integer i = 0; i < NUM_TEST_PIXELS; i = i + 1) begin
            // send pixel coords to DUT
            pixel_x = test_pixels_x[i];
            pixel_y = test_pixels_y[i];

            // capture prng values used for multiplication
            prng_x_fxpt[i] = DUT.offset_x;
            prng_y_fxpt[i] = DUT.offset_y;

            // wait for multiply IP to sample inputs
            @(posedge clk);

            // wait 4 cycle latency before storing DUT output
            repeat (4) @(posedge clk);

            // store DUT output for this sample
            actual_rays[i] = generated_ray;
        end
    endtask

    task automatic compute_expected();
        // calculate sensor plane width and height
        real vert_fov_rad;
        real sensor_plane_height;
        real sensor_plane_width;

        vert_fov_rad = FOV_DEGREES * DEG2RAD;
        sensor_plane_height = 2 * $atan(vert_fov_rad);
        sensor_plane_width = (real'(PIXEL_WIDTH) / real'(PIXEL_HEIGHT)) * sensor_plane_height;

        for (integer i = 0; i < NUM_TEST_PIXELS; i = i + 1) begin
            // convert fxpt offests from prng to real decimal offsets
            prng_x[i] = real'(prng_x_fxpt[i]) / 65536.0; // 16 fractional bits
            prng_y[i] = real'(prng_y_fxpt[i]) / 65536.0;
            
            // calculate camera space x and y
            expected_dir_x[i] = ((test_pixels_x[i] + prng_x[i]) / PIXEL_WIDTH * sensor_plane_width) - (sensor_plane_width / 2);
            expected_dir_y[i] = ((test_pixels_y[i] + prng_y[i]) / PIXEL_HEIGHT * sensor_plane_height) - (sensor_plane_height / 2);

        end

    endtask

    initial begin
        // generate pixel values for test stimulus
        for (integer i = 0; i < NUM_TEST_PIXELS; i = i + 1) begin
            test_pixels_x[i] = $urandom_range(PIXEL_WIDTH-1, 0);
            test_pixels_y[i] = $urandom_range(PIXEL_HEIGHT-1, 0);
        end

        // reset sequence
        clk = 0;
        rst_n = 0;
        pixel_x = '0;
        pixel_y = '0;
        stall = 1;
        
        @(posedge clk)
        @(posedge clk)

        stall <= 0;
        rst_n <= 1;
        
        @(posedge clk)
        @(posedge clk)

        // apply stimulus
        test_dut();

        // calculate expected rays
        compute_expected();

        // check_output
        for (integer i = 0; i < NUM_TEST_PIXELS; i = i + 1) begin
            automatic real actual_x = real'(actual_rays[i].dir.x) / 65536.0;
            automatic real actual_y = real'(actual_rays[i].dir.y) / 65536.0;

            automatic real diff_x = actual_x - expected_dir_x[i];
            automatic real diff_y = actual_y - expected_dir_y[i];

            if (abs_real(diff_x) > ERROR_THRESHOLD) begin
                num_errors = num_errors + 1;
                $error("X direction mismatch. Expected %f, got %f", expected_dir_x[i], actual_x);
            end else begin
                $display("Matched X direction for test pixel %d", i);
            end

            if (abs_real(diff_y) > ERROR_THRESHOLD) begin
                num_errors = num_errors + 1;
                 $error("Y direction mismatch. Expected %f, got %f", expected_dir_y[i], actual_y);
            end else begin
                $display("Matched Y direction for test pixel %d", i);
            end
        end

        assert(num_errors === 0) else begin
            $fatal("Actual output did not match expected output. Number of errors: %0d", num_errors);
            $finish();
        end

        $display("Test Passed!");
        $finish();
    end

endmodule