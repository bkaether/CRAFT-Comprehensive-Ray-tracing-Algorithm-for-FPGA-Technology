`timescale 1ns/1ps

`include "../data_macros.sv"

module generate_ray_tb();

    // testbench knobs
    localparam NUM_TEST_PIXELS = 50;
    localparam PIXEL_WIDTH = 800;
    localparam PIXEL_HEIGHT = 600;
    localparam FOV_DEGREES = 70;
    localparam ERROR_THRESHOLD = 0.01;

    // error counter
    int num_errors = 0;

    // test vector inputs
    int test_pixels_x[NUM_TEST_PIXELS];
    int test_pixels_y[NUM_TEST_PIXELS];

    // result arrays
    real expected_dir_x[NUM_TEST_PIXELS];
    real expected_dir_y[NUM_TEST_PIXELS];
    real expected_dir_z[NUM_TEST_PIXELS];

    ray actual_rays[NUM_TEST_PIXELS];

    // random values used by the hardware for each calculation in Q0.16 fixed point format, for use in calculating expected output
    bit [15:0] prng_x_fxpt[NUM_TEST_PIXELS];
    bit [15:0] prng_y_fxpt[NUM_TEST_PIXELS];
    // real decimal random values used by hardware
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

    integer i;

    always #4 clk = ~clk;

    generate_ray DUT (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .stall(stall),

        .generated_ray(generated_ray)
    );

    task test_dut();
        for (i = 0; i < NUM_TEST_PIXELS; i = i + 1) begin
            // send pixel coords to DUT
            pixel_x = test_pixels_x[i];
            pixel_y = test_pixels_y[i];

            // capture prng values used
            prng_x_fxpt[i] = DUT.offset_x;
            prng_y_fxpt[i] = DUT.offset_y;

            // wait 4 cycle latency before storing DUT output
            repeat (4) @(posedge clk);

            // store DUT output for this sample
            actual_rays[i] = generated_ray;
        end
    endtask

    task compute_expected();
        // calculate sensor plane width and height
        real vert_fov_rad;
        real sensor_plane_height;
        real sensor_plane_width;

        vert_fov_rad = (FOV_DEGREES * $pi) / 180;
        sensor_plane_height = 2 * $atan(vert_fov_rad);
        sensor_plane_width = (PIXEL_WIDTH / PIXEL_HEIGHT) * sensor_plane_height;

        for (i = 0; i < NUM_TEST_PIXELS; i = i + 1) begin
            // convert fxpt offests from prng to real decimal offsets
            prng_x[i] = prng_x_fxpt[i] / 65536; // 16 fractional bits
            prng_y[i] = prng_y_fxpt[i] / 65536;
            
            // calculate camera space x and y
            expected_dir_x[i] = ((test_pixels_x[i] + prng_x[i]) / PIXEL_WIDTH * sensor_plane_width) - (sensor_plane_width / 2);
            expected_dir_y[i] = ((test_pixels_y[i] + prng_y[i]) / PIXEL_HEIGHT * sensor_plane_height) - (sensor_plane_height / 2);
            expected_dir_z[i] = -1;

        end

    endtask

    initial begin
        // generate pixel values for test stimulus
        for (i = 0; i < NUM_TEST_PIXELS; i = i + 1) begin
            test_pixels_x[i] = $urandomrange(0, 800);
            test_pixels_y[i] = $urandomrange(0, 600);
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
        for (i = 0; i < NUM_TEST_PIXELS; i = i + 1) begin
            if ($abs(actual_rays[i].dir.x - expected_dir_x[i]) > ERROR_THRESHOLD) begin
                num_errors = num_errors + 1;
            end

            if ($abs(actual_rays[i].dir.y - expected_dir_y[i]) > ERROR_THRESHOLD) begin
                num_errors = num_errors + 1;
            end
        end

        assert(num_errors == 0)

        $display("Test Finsihed");
        $finish();
    end

endmodule