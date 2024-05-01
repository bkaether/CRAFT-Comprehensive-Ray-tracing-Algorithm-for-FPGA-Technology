`timescale  1ps/1ps

module ray_dir_inverse_tb();

    reg clk;
    reg stall;
    vec3 ray_dir;

    vec3_18_18 inv_ray_dir;
    wire [2:0] div_by_zero;

    always #5 clk = ~clk;

    ray_dir_inverse DUT (
        .clk(clk),
        .stall(stall),
        .ray_dir(ray_dir),

        .inv_ray_dir(inv_ray_dir),
        .div_by_zero(div_by_zero)
    );

    initial begin
        clk <= 1;
        stall <= 1;
        ray_dir <= '0;
        #40
        ray_dir.x <= 8192; // 2^13 = 1/8
        ray_dir.y <= 2048; // 2^11 = 1/32
        ray_dir.z <= 0;    // include this to observe div by zero behavior
        #40
        stall <= 0;
        #500
        $display("Test Finsihed");
        $finish();
    end

endmodule