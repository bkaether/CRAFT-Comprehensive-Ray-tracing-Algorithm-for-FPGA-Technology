`include "data_macros.sv"

import data_structs::*;

module path_tracer_top (
    input wire sysclk,
    input wire rst_n,

    output logic hit,
    output vec2 range_out
);
    vec3 ray_orig = '{x: 0, y: 0, z: 0};
    vec3 ray_dir = '{x: 5, y: 5, z: 5};
    vec2 prev_range = '{x: `INFINITY_24, y: `NEGATIVE_INFINITY_24};

    vec3 max_point = '{x: 10, y: 10, z: 10};
    bbox box = '{min: ray_orig, max: max_point};

    ray_bbox_intersect ray_bbox_intersect_i (
        .sysclk(sysclk),
        .rst_n(rst_n),
        .ray_orig(ray_orig),
        .inv_ray_dir(ray_dir),
        .box(box),
        .prev_range(prev_range),

        .hit(hit),
        .range_out(range_out)
    );
    
endmodule