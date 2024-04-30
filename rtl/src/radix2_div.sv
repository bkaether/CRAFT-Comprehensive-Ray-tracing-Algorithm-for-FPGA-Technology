`timescale  1ps/1ps

module radix2_div (
    input wire clk,
    input wire clk_en,

    input wire divisor_tvalid,
    input logic signed [27:0] divisor,
    input wire dividend_tvalid,
    input logic signed [17:0] dividend,

    output wire tvalid,
    output wire div_by_zero,
    output logic signed [35:0] result
);

    logic signed [31:0] divisor_padded; 
    assign divisor_padded = divisor;

    logic signed [23:0] dividend_padded;
    assign dividend_padded = dividend;
    
    wire signed [39:0] tdata;

    div_gen_0 div_gen_i (
        .aclk(clk),                                 // input wire aclk
        .aclken(clk_en),                            // input wire aclken
        .s_axis_divisor_tvalid(divisor_tvalid),     // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(divisor_padded),             // input wire [31 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(dividend_tvalid),   // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(dividend_padded),           // input wire [23 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(tvalid),                // output wire m_axis_dout_tvalid
        .m_axis_dout_tuser(div_by_zero),            // output wire [0 : 0] m_axis_dout_tuser
        .m_axis_dout_tdata(tdata)                   // output wire [39 : 0] m_axis_dout_tdata
    );

    wire signed [35:0] quotient = {tdata[36:19], 18'd0};
    wire signed [18:0] fraction = tdata[18:0];

    assign result = quotient + fraction;

endmodule
