`timescale 1ns/1ps

package data_structs_pkg;

    typedef enum logic [7:0] {
        LAMBERTIAN = 8'd0,
        MIRROR     = 8'd1
    } material_t;

    typedef struct packed {
        logic signed [27:0] x;
        logic signed [27:0] y;
    } vec2_t;

    typedef struct packed {
        logic signed [48:0] min;
        logic signed [48:0] max;
    } range_t;

    typedef struct packed {
        logic signed [27:0] x;
        logic signed [27:0] y;
        logic signed [27:0] z;
    } vec3_t;

    typedef struct packed {
        logic signed [27:0] x;
        logic signed [27:0] y;
        logic signed [27:0] z;
    } point_t;

    // Q1.15
    typedef struct packed {
        logic [15:0] r;
        logic [15:0] g;
        logic [15:0] b;
    } spectrum_t;

    typedef struct packed {
        logic [7:0] r;
        logic [7:0] g;
        logic [7:0] b;
    } rgb_t;

    typedef struct packed {
        point_t orig;
        vec3_t dir; 
    } ray_t;

    typedef struct packed {
        logic signed [35:0] x;
        logic signed [35:0] y;
        logic signed [35:0] z;
    } vec3_18_18_t;

    typedef struct packed {
        point_t min;
        point_t max;
    } bbox_t;

    typedef struct packed {
        vec3_t v0;
        vec3_t v1;
        vec3_t v2;
        vec3_t normal;
        material_t mat;
        spectrum_t color;
    } triangle_t;

    typedef struct packed {
        bbox_t box;
        logic [15:0] start;
        logic [15:0] size;
        logic [15:0] left;
        logic [15:0] right;
    } bvh_node_t;

    typedef enum logic [31:0] { PIXEL_SAMPLE_SALT } rng_salt_t;

    localparam logic [9:0] PIXEL_WIDTH = 10'd800;
    localparam logic [9:0] PIXEL_HEIGHT = 10'd600;

    // reciprocal of pixel dimensions in fixed point format with 16 fractional bits
    localparam logic [15:0] PIXEL_WIDTH_INV_Q0_16   = 16'd82;
    localparam logic [15:0] PIXEL_HEIGHT_INV_Q0_16  = 16'd109;

    localparam logic signed [48:0] INFINITY_49             = 49'h0FFFFFFFFFFFF;
    localparam logic signed [48:0] NEGATIVE_INFINITY_49    = 49'h1000000000000;

    // value "1" in Q12.16 fixed point format
    localparam logic signed [27:0] ONE_Q12_16          = 28'h0010000;
    localparam logic signed [27:0] NEGATIVE_ONE_Q12_16 = 28'hFFF0000;

    // default struct constants
    localparam vec2_t VEC2_DEFAULT = '0;
    localparam range_t RANGE_DEFAULT = '{NEGATIVE_INFINITY_49, INFINITY_49};
    localparam vec3_t VEC3_DEFAULT = '0;
    localparam point_t POINT_DEFAULT = '0;
    localparam spectrum_t SPECTRUM_DEFAULT = '1;
    localparam ray_t RAY_DEFAULT = '0;
    localparam bbox_t BBOX_DEFAULT = '0;

    // K constants for tea hash instances
    localparam int  HASH_ROUNDS = 6;
    localparam logic [31:0] DELTA = 32'h9E3779B9;
    localparam logic [31:0] K0    = 32'hA341316C;     // any fixed 32-bit constants work;
    localparam logic [31:0] K1    = 32'hC8013EA4;     // these are commonly used in GPU TEA RNG code
    localparam logic [31:0] K2    = 32'hAD90777D;
    localparam logic [31:0] K3    = 32'h7E95761E;

endpackage
