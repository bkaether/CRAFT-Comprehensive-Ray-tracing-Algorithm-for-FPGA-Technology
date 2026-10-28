`ifndef FF_MACROS_SVH
`define FF_MACROS_SVH

// D flip flop with active high enable
`define FFLNR(Q, D, load, clk) \
always_ff @(posedge clk) begin \
  if (load) begin \
    Q <= D; \
  end \
end

// D flip flop with active high enable and synchronous active high reset
`define FFLSR(Q, D, load, rst_val, clk, rst) \
always_ff @(posedge clk) begin \
  if (rst) begin \
    Q <= rst_val; \
  end else if (load) begin \
    Q <= D; \
  end \
end

`endif
