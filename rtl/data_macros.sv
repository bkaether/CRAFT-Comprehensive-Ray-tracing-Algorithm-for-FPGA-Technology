import data_structs::*;

`ifndef DATA_MACROS_SV
`define DATA_MACROS_SV

`define PIXEL_WIDTH  10'd800
`define PIXEL_HEIGHT 10'd600

// reciprocal of pixel dimensions in fixed point format with 16 fractional bits
`define PIXEL_WIDTH_INV  82
`define PIXEL_HEIGHT_INV 109

`define LAMBERTIAN 2'd0
`define MIRROR     2'd1

`define INFINITY_28            28'h7FFFFFF
`define NEGATIVE_INFINITY_28    28'h8000000

// value "1" in Q12.16 fixed point format
`define ONE 28'h0010000

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
