`timescale  1ns/1ps

`include "../data_macros.sv"

module ray_bbox_intersect_tb();

    reg clk;
    reg rst_n;
    reg stall;
    vec3 ray_orig;
    vec3_18_18 inv_ray_dir;
    reg [2:0] div_by_zero;
    bbox box;
    // range prev_range;

    wire hit;
    // range range_out;
    wire [48:0] closest_hit_distance;

    always #4 clk = ~clk;

    ray_bbox_intersect DUT (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .ray_orig(ray_orig),
        .inv_ray_dir(inv_ray_dir),
        .div_by_zero(div_by_zero),
        .box(box),
        // .prev_range(prev_range),

        .hit(hit),
        // .range_out(range_out)
        .closest_hit_distance(closest_hit_distance)
    );

    initial begin
        clk <= 0;
        rst_n <= 0;
        stall <= 1;
        #16
        rst_n <= 1;
        #16
        stall <= 0;
        ray_orig <= vec3_default;
        inv_ray_dir.x <= (1 << 18);
        inv_ray_dir.y <= '0;
        inv_ray_dir.z <= '0;
        div_by_zero <= 3'b110;
        box.min.x <= (1 << 16);
        box.min.y <= -(1 << 16);
        box.min.z <= -(1 << 16);
        box.max.x <= (1 << 17);
        box.max.y <= (1 << 16);
        box.max.z <= (1 << 16);
        #24
        rst_n <= 1;
        stall <= 0;
        #40
        $display("Test Finsihed");
        $finish();

    end
    
endmodule