package tb_pkg;
    // constants
    localparam real PI = 3.141592653589793;
    localparam real RAD2DEG = 180.0 / PI;
    localparam real DEG2RAD = PI / 180.0;

    function automatic real abs_real(real x);
        return (x < 0.0) ? -x : x;
    endfunction

    function automatic real fxpt_to_real(int fxpt_value, int fractional_bits);
        return real'(fxpt_value) / (1 << fractional_bits);
    endfunction

    function automatic bit is_close_real(real a, real b, real threshold);
        return abs_real(a - b) <= threshold;
    endfunction

endpackage