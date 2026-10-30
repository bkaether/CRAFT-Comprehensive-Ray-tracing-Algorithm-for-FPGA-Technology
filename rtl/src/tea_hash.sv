`timescale 1ns/1ps

`include "ff_macros.svh"

// TEA-based counter hash: 64-bit block in, 64-bit block out (a permutation)
// All values are unsigned 32-bit; all arithmetic wraps mod 2^32; shifts are logical

// THE LATENCY OF THIS MODULE IS 2*ROUNDS CYCLES, DEFAULT LATENCY IS 12 CYCLES
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

    // these pipes need 2*rounds stages due to the extra flop in the v0/v1 path needed to break up combinational logic
    logic [USER_WIDTH-1:0] user_pipe [(2*ROUNDS)+1];    
    logic                  vld_pipe  [(2*ROUNDS)+1];

    assign v0_pipe[0]   = key_i;
    assign v1_pipe[0]   = SALT;
    assign user_pipe[0] = user_i;
    assign vld_pipe[0]  = vld_i;

    for (genvar i = 1; i <= ROUNDS; i++) begin : g_hash_pipe

        localparam [31:0] SUM = DELTA * i;
        reg [31:0] v0_mid_q;
        reg [31:0] v1_mid_q;

        // tea hash function - split into two stages to meet timing
        wire [31:0] v0_mid_d = v0_pipe[i-1] + ( ((v1_pipe[i-1] << 4) + K0) ^ (v1_pipe[i-1] + SUM) ^ ((v1_pipe[i-1] >> 5) + K1) );

        `FFLNR(v0_mid_q, v0_mid_d, ~stall_i, clk)      // comb logic just computed feeds v0_mid
        `FFLNR(v1_mid_q, v1_pipe[i-1], ~stall_i, clk)   // v1 just gets passed through to match latency

        wire [31:0] v1_pipe_d = v1_mid_q + ( ((v0_mid_q << 4) + K2) ^ (v0_mid_q + SUM) ^ ((v0_mid_q >> 5) + K3) );

        // no reset on data pipes
        `FFLNR(v0_pipe[i], v0_mid_q, ~stall_i, clk)     // now v0 gets passed through
        `FFLNR(v1_pipe[i], v1_pipe_d, ~stall_i, clk)    // now use v1 combinational logic
   
    end

    for (genvar j = 1; j <= (2*ROUNDS); j++) begin : g_passthrough_pipe

        // just passing along, no logic
        `FFLNR(user_pipe[j], user_pipe[j-1], ~stall_i, clk)         
        `FFLSR(vld_pipe[j], vld_pipe[j-1], ~stall_i, '0, clk, rst)  // control pipeline gets a reset flop

    end

    assign r0_o = v0_pipe[ROUNDS];
    assign r1_o = v1_pipe[ROUNDS];
    assign user_o = user_pipe[2*ROUNDS];
    assign vld_o = vld_pipe[2*ROUNDS];
    
endmodule