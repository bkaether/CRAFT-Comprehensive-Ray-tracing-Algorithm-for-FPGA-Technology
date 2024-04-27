`include "data_macros.sv"

import data_structs::*;

module path_tracer_top (
    input wire sysclk,
    input wire rst_n,
    input vec3 ray_orig_in,

    output logic hit_out
);
    vec3 ray_orig_reg;
    vec3 ray_dir_reg;
    
    `FF(sysclk, rst_n, vec3_default, ray_orig_reg, ray_orig_in)
    `FF(sysclk, rst_n, vec3_default, ray_dir_reg, ray_orig_in)
    
    vec2 prev_range = '{x: `NEGATIVE_INFINITY_24, y: `INFINITY_24};
    
    wire nxt_hit;
    vec2 nxt_range;

    reg hit_reg;
    vec2 range_reg;

    vec3 max_point = '{x: 10, y: 10, z: 10};
    bbox box = '{min: point_default, max: max_point};

    ray_bbox_intersect ray_bbox_intersect_i (
        .clk(sysclk),
        .ray_orig(ray_orig_reg),
        .inv_ray_dir(ray_dir_reg),
        .box(box),
        .prev_range(prev_range),

        .hit(nxt_hit),
        .range_out(nxt_range)
    );
    
    `FF(sysclk, rst_n, 1'b0, hit_reg, nxt_hit)
    `FF(sysclk, rst_n,  range_default, range_reg, nxt_range)

    assign hit_out = hit_reg;
    
endmodule