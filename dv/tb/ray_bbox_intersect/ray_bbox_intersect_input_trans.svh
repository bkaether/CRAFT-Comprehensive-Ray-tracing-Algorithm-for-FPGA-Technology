class ray_bbox_intersect_input_trans;

    // constraint constants
    const int ONE_Q1_16 = 17'h10000;
    const int ABS_DIR_WIDTH = 17;

    rand point_t ray_orig;

    // Q1.16 (not signed because sign bit fields carry that info between ray dir inverse and ray bbox intersect)
    rand bit [16:0] inv_dir_x;
    rand bit [16:0] inv_dir_y;
    rand bit [16:0] inv_dir_z;

    rand bit sign_x;
    rand bit sign_y;
    rand bit sign_z;

    rand bit div_by_zero_x;
    rand bit div_by_zero_y;
    rand bit div_by_zero_z;

    rand bit [4:0] shift_x;
    rand bit [4:0] shift_y;
    rand bit [4:0] shift_z;

    rand bbox_t box;

    rand bit vld;
    rand bit stall;


    // ray dir inverse output guaranteed to be in the range (0.5, 1] in Q1.16 format
    constraint inv_dir_mantissa_c {
        inv_dir_x <= ONE_Q1_16;
        inv_dir_x <= ONE_Q1_16;
        inv_dir_x <= ONE_Q1_16;
    }

    // leading zero count has a maximum value of the bit width of the absolute value of the direciton, which in the rtl is currently 17
    constraint shift_c {
        div_by_zero_x -> shift_x == ABS_DIR_WIDTH;
        div_by_zero_y -> shift_y == ABS_DIR_WIDTH;
        div_by_zero_z -> shift_z == ABS_DIR_WIDTH;

        !div_by_zero_x -> shift_x < ABS_DIR_WIDTH;
        !div_by_zero_y -> shift_y < ABS_DIR_WIDTH;
        !div_by_zero_z -> shift_z < ABS_DIR_WIDTH;
    }

    constraint div_by_zero_c {
        div_by_zero_x dist {1'b0 := 2, 1'b1 := 98};
        div_by_zero_y dist {1'b0 := 2, 1'b1 := 98};
        div_by_zero_z dist {1'b0 := 2, 1'b1 := 98};
    }

    // bbox must be at least 10 units wide on all axes
    // this also handles the max needing to be greater than the min, since the boxes min/mox points are signed
    constraint bbox_c {
        bbox.max.x - box.min.x > 10;
        bbox.max.y - box.min.y > 10;
        bbox.max.z - box.min.z > 10;
    }

endclass