`timescale 1ns/1ps

`include "ff_macros.svh"

// 16 bit xor shift based PRNG
module xor_prng #(
    parameter SEED = 16'h1ACE
) (
    input wire clk,
    input wire rst,
    input wire en_i,

    output wire [15:0] rand_num_o
);

    // register for holding the current state/initial output
    reg  [15:0] state_q;
    wire [15:0] state_d;

    // xorshift algorithm
    wire [15:0] temp = state_q ^ (state_q >> 7);
    wire [15:0] temp2 = temp ^ (temp << 9);
    assign state_d = temp2 ^ (temp2 >> 8);

    // state FF
    `FFLSR (state_q, state_d, en_i, SEED, clk, rst)

    assign rand_num_o = state_q;

    
endmodule