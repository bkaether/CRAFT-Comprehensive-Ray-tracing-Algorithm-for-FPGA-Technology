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

    // Q1.16
    typedef struct packed {
        logic [16:0] r;
        logic [16:0] g;
        logic [16:0] b;
    } spectrum;

    typedef struct packed {
        logic [7:0] r;
        logic [7:0] g;
        logic [7:0] b;
    } rgb;

    typedef struct packed {
        point orig;
        vec3 dir; 
    } ray;

    typedef struct packed {
        logic signed [35:0] x;
        logic signed [35:0] y;
        logic signed [35:0] z;
    } vec3_18_18;

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
