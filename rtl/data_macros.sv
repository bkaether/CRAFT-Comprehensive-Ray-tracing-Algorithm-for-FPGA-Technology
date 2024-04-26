import data_structs::*;

`ifndef DATA_MACROS_SV
`define DATA_MACROS_SV

`define LAMBERTIAN 2'd0
`define MIRROR     2'd1

`define INFINITY_24             24'h7FFFFF
`define NEGATIVE_INFINITY_24    24'h800000

// value "1" in Q12.12 fixed point format
`define ONE 24'h001000

// D Flip Flop with active low reset
`define FF(clk, rst_n, rst_val, Q, D) \
always_ff @(posedge clk) begin \
  if (!rst_n) begin \
    Q <= rst_val; \
  end else begin \
    Q <= D; \
  end \
end

// D flip flop with active high enable and active low reset
`define FF_EN(clk, rst_n, rst_val, en, Q, D) \
always_ff @(posedge clk) begin \
  if (!rst_n) begin \
    Q <= rst_val; \
  end else if (en) begin \
    Q <= D; \
  end \
end

`endif
