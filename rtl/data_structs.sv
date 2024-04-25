`define LAMBERTIAN 2'd0
`define MIRROR     2'd1

`define INFINITY_24             24'h7FFFFF
`define NEGATIVE_INFINITY_24    24'h800000

typedef struct packed {
    logic signed [23:0] x;
    logic signed [23:0] y;
} vec2;

typedef struct packed {
    logic signed [23:0] x;
    logic signed [23:0] y;
    logic signed [23:0] z;
} vec3;

typedef struct packed {
    logic signed [23:0] x;
    logic signed [23:0] y;
    logic signed [23:0] z;
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