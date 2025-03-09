`timescale  1ns/1ps

`include "../data_macros.sv"

module ray_bvh_intersect (
    input wire clk,
    input wire rst_n,
    input vec3 ray_orig,
    input vec3_18_18 inv_ray_dir,
    input wire [2:0] div_by_zero,

    output wire stall,
    output wire hit,
    output wire [48:0] closest_hit_distance,

    // BRAM NODE MEMORY INTERFACE SIGNALS
    /////////////////////////////////////////
    input wire [255:0] doutb_node_mem,

    output wire clkb_node_mem,
    output wire rstb_node_mem,
    output wire enb_nde_mem,
    output wire [31:0] addrb_node_mem,
    output wire [255:0] dinb_node_mem,
    output wire [63:0] web_node_mem
    /////////////////////////////////////////

    // BRAM PRIMITIVE MEMORY INTERFACE SIGNALS
    /////////////////////////////////////////
    // input wire [255:0] doutb_primitive_mem,

    // output wire clkb_primitive_mem,
    // output wire rstb_primitive_mem,
    // output wire enb_nde_mem,
    // output wire [31:0] addrb_primitive_mem,
    // output wire [511:0] dinb_primitive_mem,
    // output wire [63:0] web_primitive_mem
    /////////////////////////////////////////
);

    // states which will be used in BVH traversal FSM
    localparam [5:0] ROOT_NODE_READ_BBOX = 6'd0;
    localparam [5:0] ROOT_NODE_HIT_CALC_0 = 6'd1;
    localparam [5:0] ROOT_NODE_HIT_CALC_1 = 6'd2;
    localparam [5:0] ROOT_NODE_HIT_CALC_2 = 6'd3;
    localparam [5:0] NODE_READ_LEFT_BBOX = 6'd4;
    localparam [5:0] NODE_READ_RIGHT_BBOX = 6'd5;
    localparam [5:0] NODE_HIT_CALC_0 = 6'd6;
    localparam [5:0] NODE_HIT_CALC_1 = 6'd7;
    localparam [5:0] NODE_HIT_CALC_2 = 6'd8;  
    localparam [5:0] PRIMITIVE_STATE = 6'b01;
    localparam [5:0] DONE_STATE = 6'b11; 

    reg  [5:0] state;
    wire [5:0] nxt_state;
    
    // state FF
    `FF(clk, rst_n, DONE_STATE, state, nxt_state)

    assign nxt_state = (state === DONE_STATE) ? ROOT_NODE_STATE :

    // need two ray-bbox intersect modules to compute distance to each child node in parallel, so that we can
    // check the closer box first
    ray_bbox_intersect left_node_intersect_i (
        .clk(),
        .rst_n(),
        .stall(),
        .ray_orig(),
        .inv_ray_dir(),
        .div_by_zero(),
        .bbox(),

        .hit(),
        .closest_hit_distance()
    );

    ray_bbox_intersect right_node_intersect_i (
        .clk(),
        .rst_n(),
        .stall(),
        .ray_orig(),
        .inv_ray_dir(),
        .div_by_zero(),
        .bbox(),

        .hit(),
        .closest_hit_distance()
    );

    // send stall signal upstream if a ray is currently being processed
    assign stall = (state != DONE_STATE);

    
endmodule