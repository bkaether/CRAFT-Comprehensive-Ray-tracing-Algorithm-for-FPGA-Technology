package data_structs;

    typedef struct packed {
        logic signed [27:0] x;
        logic signed [27:0] y;
    } vec2;

    typedef struct packed {
        logic signed [48:0] min;
        logic signed [48:0] max;
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

    // Q1.15
    typedef struct packed {
        logic [15:0] r;
        logic [15:0] g;
        logic [15:0] b;
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

    typedef struct packed {
        vec3 v0;
        vec3 v1;
        vec3 v2;
        vec3 normal;
        logic [7:0] material;
        spectrum color;
    } triangle;

    typedef struct packed {
        bbox box;
        logic [15:0] start;
        logic [15:0] size;
        logic [15:0] left;
        logic [15:0] right;
    } bvh_node;

    // default struct constants
    const vec2 vec2_default = '0;
    const range range_default = '{49'h1000000000000, 49'h0FFFFFFFFFFFF};
    const vec3 vec3_default = '0;
    const point point_default = '0;
    const spectrum spectrum_default = '1;
    const ray ray_default = '0;
    const bbox bbox_default = '0;
    

endpackage
