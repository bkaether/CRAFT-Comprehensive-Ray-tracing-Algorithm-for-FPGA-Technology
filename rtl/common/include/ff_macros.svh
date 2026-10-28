`ifndef FF_MACROS_SVH
`define FF_MACROS_SVH

// D Flip Flop with active low reset
`define FF(clk, rst, rst_val, Q, D) \
always_ff @(posedge clk) begin \
  if (rst) begin \
    Q <= rst_val; \
  end else begin \
    Q <= D; \
  end \
end

// D flip flop with active high enable and active low reset
`define FF_EN(clk, rst, rst_val, en, Q, D) \
always_ff @(posedge clk) begin \
  if (rst) begin \
    Q <= rst_val; \
  end else if (en) begin \
    Q <= D; \
  end \
end

`endif
