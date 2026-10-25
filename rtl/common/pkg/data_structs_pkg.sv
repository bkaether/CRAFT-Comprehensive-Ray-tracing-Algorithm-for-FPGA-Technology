package data_structs_pkg;

    typedef enum logic [7:0] {
        LAMBERTIAN = 8'd0,
        MIRROR     = 8'd1
    } material;

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
        material mat;
        spectrum color;
    } triangle;

    typedef struct packed {
        bbox box;
        logic [15:0] start;
        logic [15:0] size;
        logic [15:0] left;
        logic [15:0] right;
    } bvh_node;

    localparam [9:0] PIXEL_WIDTH = 10'd800;
    localparam [9:0] PIXEL_HEIGHT = 10'd600;

    // reciprocal of pixel dimensions in fixed point format with 16 fractional bits
    localparam [15:0] PIXEL_WIDTH_INV_Q0_16   = 16'd82;
    localparam [15:0] PIXEL_HEIGHT_INV_Q0_16  = 16'd109;

    localparam signed [48:0] INFINITY_49             = 49'h0FFFFFFFFFFFF;
    localparam signed [48:0] NEGATIVE_INFINITY_49    = 49'h1000000000000;

    // value "1" in Q12.16 fixed point format
    localparam signed [27:0] ONE_Q12_16          = 28'h0010000;
    localparam signed [27:0] NEGATIVE_ONE_Q12_16 = 28'hFFF0000;

    // default struct constants
    localparam vec2 VEC2_DEFAULT = '0;
    localparam range RANGE_DEFAULT = '{NEGATIVE_INFINITY_49, INFINITY_49};
    localparam vec3 VEC3_DEFAULT = '0;
    localparam point POINT_DEFAULT = '0;
    localparam spectrum SPECTRUM_DEFAULT = '1;
    localparam ray RAY_DEFAULT = '0;
    localparam bbox BBOX_DEFAULT = '0;

endpackage
