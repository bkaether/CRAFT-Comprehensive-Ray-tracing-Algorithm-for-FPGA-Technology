`include "../data_macros.sv"

import data_structs::*;

module path_tracer_top (
    input wire sysclk,
    // input wire rst_n,
    // input wire start,
    input logic signed [31:0] divisor,

    output logic signed [34:0] result_out,
    output wire div_by_zero
);

    wire signed [23:0] dividend = 24'h010000;
    wire signed [39:0] result;

     // high radix division
     ray_inverse_div ray_inverse_div_i (
         .aclk(sysclk),                                      // input wire aclk
         .aclken(1'b1),                                  // input wire aclken
         .s_axis_divisor_tvalid(1'b1),    // input wire s_axis_divisor_tvalid
         .s_axis_divisor_tready(),    // output wire s_axis_divisor_tready
         .s_axis_divisor_tdata(divisor),      // input wire [31 : 0] s_axis_divisor_tdata
         .s_axis_dividend_tvalid(1'b1),          // input wire s_axis_dividend_tvalid
         .s_axis_dividend_tready(),  // output wire s_axis_dividend_tready
         .s_axis_dividend_tdata(dividend),    // input wire [23 : 0] s_axis_dividend_tdata
         .m_axis_dout_tvalid(),          // output wire m_axis_dout_tvalid
         .m_axis_dout_tuser(div_by_zero),            // output wire [0 : 0] m_axis_dout_tuser
         .m_axis_dout_tdata(result)            // output wire [39 : 0] m_axis_dout_tdata
     );

     assign result_out = result[33:0];



//    // radix 2 division to compare resource usage
//    radix2_div radix2_div_i (
//        .clk(sysclk),
//        .clk_en(1'b1),
//        .divisor_tvalid(1'b1),
//        .divisor(divisor),
//        .dividend_tvalid(1'b1),
//        .dividend(dividend),

//        .tvalid(),
//        .result(result),
//        .div_by_zero(div_by_zero)
//    );

//    assign result_out = result[34:0];
    
endmodule