`define LAMBERTIAN 2'd0
`define MIRROR     2'd1

typedef struct {
    logic signed [23:0] x;
    logic signed [23:0] y;
} vec2;

typedef struct {
    logic signed [23:0] x;
    logic signed [23:0] y;
    logic signed [23:0] z;
} vec3;

typedef struct {
    logic signed [23:0] x;
    logic signed [23:0] y;
    logic signed [23:0] z;
} point;

typedef struct {
    logic [11:0] r;
    logic [11:0] g;
    logic [11:0] b;
} spectrum;

typedef struct {
    point orig;
    vec3 dir; 
} ray;

typedef struct {
    point min;
    point max;
} bbox;