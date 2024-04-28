`timescale 1ps/1ps

`include "data_macros.sv"

// 12 bit xor shift based PRNG
module xor_prng #(
    parameter SEED = 16'h1ACE
) (
    input wire clk,
    input wire rst_n,
    input wire enable,

    output wire [15:0] rand_num
);

    // register for holding the current state/initial output
    reg  [15:0] state;
    wire [15:0] nxt_state;

    // xorshift algorithm
    wire [15:0] temp = state ^ (state >> 7);
    wire [15:0] temp2 = temp ^ (temp << 9);
    assign nxt_state = temp2 ^ (temp2 >> 8);

    // state FF
    `FF_EN(clk, rst_n, SEED, enable, state, nxt_state)

    // get the 12 MSBs of the 16 bit PRNG
    assign rand_num = state;

    
endmodule