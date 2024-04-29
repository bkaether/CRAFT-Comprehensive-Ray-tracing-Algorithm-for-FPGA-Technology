`timescale 1ps/1ps

`include "../data_macros.sv"

module generate_ray_tb();

    parameter pixel_w = 800;
    parameter pixel_h = 600;

    reg clk;
    reg rst_n;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    reg stall;

    ray generated_ray;

    // integer i, j;

    always #5 clk = ~clk;

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
        #20
        stall <= 0;
        rst_n <= 1;
        pixel_x <= 100;
        pixel_y <= 100;
        #10
        pixel_x <= 200;
        pixel_y <= 200;
        #10
        stall <= 1;
        pixel_x <= 300;
        pixel_y <= 300;
        #50
        stall <= 0;
        #10
        pixel_x <= 400;
        pixel_y <= 400;
        #100
        // for (i = 0; i < pixel_h; i++) begin
        //     for (j = 0; j < pixel_w; j++) begin
        //         #10
        //         pixel_x <= j;
        //         pixel_y <= i;
        //     end
        // end
        #200
        $display("Test Finsihed");
        $finish();
    end

endmodule