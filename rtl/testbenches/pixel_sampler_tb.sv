`timescale 1ps/1ps

`include "../data_macros.sv"

module pixel_sampler_tb();

    parameter pixel_w = 800;
    parameter pixel_h = 600;

    reg clk;
    reg rst_n;
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    reg stall;

    wire [16:0] normalized_x;
    wire [16:0] normalized_y;

    integer i, j;

    always #5 clk = ~clk;

    pixel_sampler DUT (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .stall(stall),

        .normalized_x(normalized_x),
        .normalized_y(normalized_y)
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