`timescale 1ns/1ps

`include "ff_macros.svh"

// TEA-based counter hash: 64-bit block in, 64-bit block out (a permutation)
// All values are unsigned 32-bit; all arithmetic wraps mod 2^32; shifts are logical

// THE LATENCY OF THIS MODULE IS ROUNDS CYCLES, DEFAULT LATENCY IS 6 CYCLES
module tea_hash 
    import data_structs_pkg::*;
#(
    parameter int ROUNDS = 6,
    parameter rng_salt_t SALT,
    parameter int USER_WIDTH = 1            // width for pass through data is a parameter so the hash module can be used for any user
) (
    input wire clk,
    input wire rst,
    
    input wire [31:0]           key_i,
    input wire [USER_WIDTH-1:0] user_i,     // data that the hash is meant for, passing through with the same latency
    input wire                  vld_i,
    input wire                  stall_i,
    
    output wire [31:0]           r0_o,
    output wire [31:0]           r1_o,
    output wire [USER_WIDTH-1:0] user_o,     // data that the hash is meant for, passing through with the same latency
    output wire                  vld_o
);

    // index 0 is the combinational input, index i is the register output of stage i
    logic [31:0]           hash_pipe_0 [ROUNDS+1];
    logic [31:0]           hash_pipe_1 [ROUNDS+1];
    logic [USER_WIDTH-1:0] user_pipe   [ROUNDS+1];
    logic                  vld_pipe    [ROUNDS+1];

    assign hash_pipe_0[0] = key_i;
    assign hash_pipe_1[0] = SALT;
    assign user_pipe[0]   = user_i;
    assign vld_pipe[0]    = vld_i;

    for (genvar i = 1; i <= ROUNDS; i++) begin : g_hash_pipe
        localparam [31:0] SUM = DELTA * i;

        // tea hash function
        wire [31:0] hash_pipe_0_d = hash_pipe_0[i-1] + ( ((hash_pipe_1[i-1] << 4) + K0) ^ (hash_pipe_1[i-1] + SUM) ^ ((hash_pipe_1[i-1] >> 5) + K1) );
        wire [31:0] hash_pipe_1_d = hash_pipe_1[i-1] + ( ((hash_pipe_0_d << 4) + K2) ^ (hash_pipe_0_d + SUM) ^ ((hash_pipe_0_d >> 5) + K3) );

        // no reset on data pipes
        `FFLNR(hash_pipe_0[i], hash_pipe_0_d, ~stall_i, clk)
        `FFLNR(hash_pipe_1[i], hash_pipe_1_d, ~stall_i, clk)        
        `FFLNR(user_pipe[i], user_pipe[i-1], ~stall_i, clk)         // just passing along, no logic

        // control pipeline gets a reset flop
        `FFLSR(vld_pipe[i], vld_pipe[i-1], ~stall_i, '0, clk, rst)  // just passing along, no logic
    end

    assign r0_o = hash_pipe_0[ROUNDS];
    assign r1_o = hash_pipe_1[ROUNDS];
    assign user_o = user_pipe[ROUNDS];
    assign vld_o = vld_pipe[ROUNDS];
    
endmodule