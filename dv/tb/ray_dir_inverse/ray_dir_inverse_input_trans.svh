import data_structs_pkg::*;

class ray_dir_inverse_input_trans;

    typedef enum {DIR_ZERO, DIR_POS_ONE, DIR_NEG_ONE, DIR_TINY, DIR_ANY} dir_case_t;

    unit_vec3_t unit_vec;
    rand bit vld;

    rand logic signed [17:0] dir  [3];   // SQ1.16 x/y/z
    rand dir_case_t          dcase[3];

    // how often each kind of component appears
    constraint c_dir_case_dist {
        foreach (dcase[i]) {
            dcase[i] dist { DIR_ZERO := 3, DIR_POS_ONE := 2, DIR_NEG_ONE := 2, DIR_TINY := 3, DIR_ANY := 90 };
        }
    }

    // what each case means
    constraint c_dir_values {
        foreach (dir[i]) {
            dcase[i] == DIR_ZERO    -> dir[i] == 0;
            dcase[i] == DIR_POS_ONE -> dir[i] ==  18'sh10000;                         //  1.0 in SQ1.16
            dcase[i] == DIR_NEG_ONE -> dir[i] == -18'sh10000;                         // -1.0
            dcase[i] == DIR_TINY    -> dir[i] inside {[-255:255]} && dir[i] != 0;     // large shifts
            dcase[i] == DIR_ANY     -> dir[i] inside {[-18'sh10000:18'sh10000]};      // [-1, 1]
        }
    }

    function void post_randomize();

        unit_vec.x = dir[0];
        unit_vec.y = dir[1];
        unit_vec.z = dir[2];

    endfunction

endclass