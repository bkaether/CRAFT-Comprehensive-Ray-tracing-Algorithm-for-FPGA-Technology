`timescale 1ns/1ps

`include "../data_macros.sv"

module generate_ray_tb();

    // testbench knobs
    localparam NUM_PIXELS = 50;
    localparam PIXEL_WIDTH = 800;
    localparam PIXEL_HEIGHT = 600;

    // test vectors
    int pixel_X[NUM_PIXELS];
    int pixel_Y[NUM_PIXELS];

    // result arrays
    real expected_dir_x[NUM_PIXELS];
    real expected_dir_y[NUM_PIXELS];
    real expected_dir_z[NUM_PIXELS];

    ray actual_rays[NUM_PIXELS];

    // DUT signals
    // inputs
    reg clk;
    reg rst_n;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    reg stall;

    // outputs
    ray generated_ray;

    // integer i, j;

    always #4 clk = ~clk;

    generate_ray DUT (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .stall(stall),

        .generated_ray(generated_ray)
    );

    initial begin
        clk <= 1;
        rst_n <= 0;
        pixel_x <= '0;
        pixel_y <= '0;
        stall <= 1;
        #16
        stall <= 0;
        rst_n <= 1;
        pixel_x <= 100;
        pixel_y <= 100;
        #8
        pixel_x <= 200;
        pixel_y <= 200;
        #8
        stall <= 1;
        pixel_x <= 500;
        pixel_y <= 500;
        #40
        stall <= 0;
        #8
        pixel_x <= 700;
        pixel_y <= 700;
        #80
        // for (i = 0; i < pixel_h; i++) begin
        //     for (j = 0; j < pixel_w; j++) begin
        //         #10
        //         pixel_x <= j;
        //         pixel_y <= i;
        //     end
        // end
        #160
        $display("Test Finsihed");
        $finish();
    end

endmodule