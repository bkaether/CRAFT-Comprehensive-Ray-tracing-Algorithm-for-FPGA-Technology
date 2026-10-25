package tb_pkg;
    // constants
    localparam real PI = 3.141592653589793;
    localparam real RAD2DEG = 180.0 / PI;
    localparam real DEG2RAD = PI / 180.0;

    function automatic real abs_real(real x);
        return (x < 0.0) ? -x : x;
    endfunction

endpackage