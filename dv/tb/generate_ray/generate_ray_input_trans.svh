class generate_ray_input_trans;

    rand bit [9:0] pixel_x;
    rand bit [9:0] pixel_y;
    rand bit vld;
    rand bit stall;

    constraint pixel_range_c {
        pixel_x >= 0;
        pixel_x < 800;

        pixel_y >= 0;
        pixel_y < 600;
    }

endclass