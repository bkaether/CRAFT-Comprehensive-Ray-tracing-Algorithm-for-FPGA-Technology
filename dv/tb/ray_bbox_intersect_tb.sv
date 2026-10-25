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

    wire hit;
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

        .hit(hit),
        .closest_hit_distance(closest_hit_distance)
    );

    const bbox in_front = '{
        min: '{x: (1 << 16), y: -(1 << 16), z: -(1 << 16)},
        max: '{x: (1 << 17), y: (1 << 16), z: (1 << 16)}
    };

    const bbox behind = '{
        min: '{x: -(1 << 17), y: -(1 << 16), z: -(1 << 16)},
        max: '{x: -(1 << 16), y: (1 << 16), z: (1 << 16)}
    };

    const bbox above = '{
        min: '{x: -(1 << 16), y: (1 << 16), z: -(1 << 16)},
        max: '{x: (1 << 16), y: (1 << 17), z: (1 << 16)}
    };

    const bbox _inside = '{
        min: '{x: -(1 << 16), y: -(1 << 16), z: -(1 << 16)},
        max: '{x: (1 << 17), y: (1 << 17), z: (1 << 17)}
    };

    const vec3_18_18 positive_x_dir = '{
        x: (1 << 18),
        y: '0,
        z: '0
    };

    const vec3_18_18 negative_x_dir = '{
        x: -(1 << 18),
        y: '0,
        z: '0
    };
    

    initial begin
        clk <= 1;
        rst_n <= 0;
        stall <= 1;
        #16
        rst_n <= 1;
        #16
        stall <= 0;
        ray_orig <= vec3_default;
        inv_ray_dir <= positive_x_dir;
        div_by_zero <= 3'b110;
        box <= in_front;
        #8
        box <= behind;
        #8
        box <= _inside;
        #8
        box <= above;
        #8
        inv_ray_dir <= negative_x_dir;
        box <= behind;
        #8
        box <= in_front;
        #8
        box <= _inside;
        #8
        box <= above;
        #40
        $display("Test Finsihed");
        $finish();

    end
    
endmodule