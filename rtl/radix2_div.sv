`ifndef RADIX2_DIV
`define RADIX2_DIV
`timescale  1ps/1ps

module radix2_div (
    input wire sysclk,
    input logic divisor_tvalid,
    input logic signed [23:0] divisor,
    input logic dividend_tvalid,
    input logic signed [23:0] dividend,

    output logic tvalid,
    output logic signed [23:0] result
);

    wire signed [39:0] tdata;

    div_gen_0 div_gen_0_i (
        .aclk(sysclk),
        .s_axis_divisor_tvalid(divisor_tvalid),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(divisor),      // input wire [23 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(dividend_tvalid),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(dividend),    // input wire [23 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(tvalid),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(tdata)            // output wire [39 : 0] m_axis_dout_tdata
    );

    wire signed [23:0] quotient = (tvalid ? {tdata[24:13], 12'd0} : 24'd0);
    wire signed [12:0] fraction = tvalid ? tdata[12:0] : 13'd0;

    assign result = quotient + fraction;

endmodule

`endif