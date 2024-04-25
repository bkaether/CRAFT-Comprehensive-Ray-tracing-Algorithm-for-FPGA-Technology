`timescale  1ps/1ps

class tb_input;

        rand bit signed [23:0] dividend;
        rand bit signed [23:0] divisor;

endclass //tb_input

module radix2_div_tb();

    logic clk;
    logic signed [23:0] dividend;
    logic        dividend_tvalid;
    logic signed [23:0] divisor;
    logic        divisor_tvalid;

    logic        tvalid;
    logic signed [23:0] result;

    always #5 clk = ~clk;

    radix2_div DUT (
        .sysclk(clk),
        .divisor_tvalid(divisor_tvalid),    // input wire s_axis_divisor_tvalid
        .divisor(divisor),      // input wire [23 : 0] s_axis_divisor_tdata
        .dividend_tvalid(dividend_tvalid),  // input wire s_axis_dividend_tvalid
        .dividend(dividend),    // input wire [23 : 0] s_axis_dividend_tdata
        .tvalid(tvalid),          // output wire m_axis_dout_tvalid
        .result(result)            // output wire [39 : 0] m_axis_dout_tdata
    );

    // data structures for results
    logic signed [23:0] test_dividends [256];
    logic signed [23:0] test_divisors [256];
    logic signed [23:0] test_results [256];

    tb_input rand_vals;
    real epsilon = 1e-3;
    int total_errors = 0;
    logic [7:0] in_index = 0;
    logic [7:0] out_index = 0;

    always @(posedge clk) begin
        if (tvalid) begin
            test_results[out_index] <= result;
            out_index <= out_index + 1;
        end
    end
    
    initial begin
        clk <= 0;
        dividend_tvalid <= 0;
        divisor_tvalid <= 0;
        dividend <= 0;
        divisor <= 0;
        rand_vals = new();
        #10
        
        // begin randomized testing
        repeat (256) begin
            #10
            assert(rand_vals.randomize());

            // set up test arrays
            test_dividends[in_index] = rand_vals.dividend;
            test_divisors[in_index]  = rand_vals.divisor;
            in_index = in_index + 1;

            dividend <= rand_vals.dividend;
            divisor <= rand_vals.divisor;
            dividend_tvalid <= 1;
            divisor_tvalid <= 1;

            

            #10
            dividend_tvalid <= 0;
            divisor_tvalid <= 0;
        end
        #1000 // wait for all results

        for (int i = 0; i < 256; i = i + 1) begin
            automatic real real_dividend = real'(test_dividends[i]);
            automatic real real_divisor = real'(test_divisors[i]);
            automatic real true_result = real_dividend / real_divisor;
            automatic real fxp_result = (real'(test_results[i]) / 4096);

            automatic real difference = (true_result > fxp_result) ? (true_result - fxp_result) : (fxp_result - true_result);

            assert (difference < epsilon)
            else  begin 
                $display("Incorrect Result at index %d: difference = %f", i, difference);
                $display("%d / %d = %f", real_dividend, real_divisor, fxp_result);
                total_errors = total_errors + 1;
            end
        end

        $display("Total Errors = %d", total_errors);

        $display("Test finished");
        $finish();
    end
    
endmodule
