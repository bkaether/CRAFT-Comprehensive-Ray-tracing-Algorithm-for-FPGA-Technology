package data_structs;

    typedef struct packed {
        logic signed [27:0] x;
        logic signed [27:0] y;
    } vec2;

    typedef struct packed {
        logic signed [27:0] min;
        logic signed [27:0] max;
    } range;

    typedef struct packed {
        logic signed [27:0] x;
        logic signed [27:0] y;
        logic signed [27:0] z;
    } vec3;

    typedef struct packed {
        logic signed [27:0] x;
        logic signed [27:0] y;
        logic signed [27:0] z;
    } point;

    typedef struct packed {
        logic [11:0] r;
        logic [11:0] g;
        logic [11:0] b;
    } spectrum;

    typedef struct packed {
        point orig;
        vec3 dir; 
    } ray;

    typedef struct packed {
        point min;
        point max;
    } bbox;

    // default struct constants
    const vec2 vec2_default = '0;
    const range range_default = '{28'h8000000, 28'h7FFFFFF};
    const vec3 vec3_default = '0;
    const point point_default = '0;
    const spectrum spectrum_default = '1;
    const ray ray_default = '0;
    const bbox bbox_default = '0;
    

endpackage
