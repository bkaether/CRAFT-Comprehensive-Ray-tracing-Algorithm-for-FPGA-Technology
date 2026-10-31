`timescale 1ns/1ps

`include "ff_macros.svh"

// TEA-based counter hash: 64-bit block in, 64-bit block out (a permutation)
// All values are unsigned 32-bit; all arithmetic wraps mod 2^32; shifts are logical

// THE LATENCY OF THIS MODULE IS 2*ROUNDS CYCLES - DEFAULT LATENCY IS 12 CYCLES
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

    // index 0 is the combinational input, index i is the output after round i
    logic [31:0]           v0_pipe   [ROUNDS+1];
    logic [31:0]           v1_pipe   [ROUNDS+1];
    logic [USER_WIDTH-1:0] user_pipe [ROUNDS+1];    
    logic                  vld_pipe  [ROUNDS+1];

    assign v0_pipe[0]   = key_i;
    assign v1_pipe[0]   = SALT;
    assign user_pipe[0] = user_i;
    assign vld_pipe[0]  = vld_i;

    // tea hash function - split into two stages to meet timing
    for (genvar i = 1; i <= ROUNDS; i++) begin : g_hash_pipe

        localparam logic [31:0] SUM = DELTA * i;

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // ROUND i, LOGIC STAGE 1 OF 2
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        logic [31:0] v0_mid_d;
        logic [31:0] v0_mid_q;
        logic [31:0] v1_mid_d;
        logic [31:0] v1_mid_q; 

        logic [USER_WIDTH-1:0] user_mid_d;
        logic [USER_WIDTH-1:0] user_mid_q; 
        logic vld_mid_d;
        logic vld_mid_q;

        assign v0_mid_d = v0_pipe[i-1] + ( ((v1_pipe[i-1] << 4) + K0) ^ (v1_pipe[i-1] + SUM) ^ ((v1_pipe[i-1] >> 5) + K1) );
        assign v1_mid_d = v1_pipe[i-1];
        assign user_mid_d = user_pipe[i-1];
        assign vld_mid_d = vld_pipe[i-1];

        `FFLNR(v0_mid_q, v0_mid_d, ~stall_i, clk)      // comb logic just computed feeds v0_mid
        `FFLNR(v1_mid_q, v1_mid_d, ~stall_i, clk)      // v1 just gets passed through to match latency
        `FFLNR(user_mid_q, user_mid_d, ~stall_i, clk)
        `FFLSR(vld_mid_q, vld_mid_d, ~stall_i, '0, clk, rst)

        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // ROUND i, LOGIC STAGE 2 OF 2
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        logic [31:0] v0_pipe_d;
        logic [31:0] v1_pipe_d;

        logic [USER_WIDTH-1:0] user_pipe_d;
        logic vld_pipe_d;

        assign v0_pipe_d = v0_mid_q;
        assign v1_pipe_d = v1_mid_q + ( ((v0_mid_q << 4) + K2) ^ (v0_mid_q + SUM) ^ ((v0_mid_q >> 5) + K3) );
        assign user_pipe_d = user_mid_q;
        assign vld_pipe_d = vld_mid_q;

        `FFLNR(v0_pipe[i], v0_pipe_d, ~stall_i, clk)    // now v0 gets passed through
        `FFLNR(v1_pipe[i], v1_pipe_d, ~stall_i, clk)    // now use v1 combinational logic
        `FFLNR(user_pipe[i], user_pipe_d, ~stall_i, clk)
        `FFLSR(vld_pipe[i], vld_pipe_d, ~stall_i, '0, clk, rst)
   
    end

    assign r0_o = v0_pipe[ROUNDS];
    assign r1_o = v1_pipe[ROUNDS];
    assign user_o = user_pipe[ROUNDS];
    assign vld_o = vld_pipe[ROUNDS];
    
endmodule