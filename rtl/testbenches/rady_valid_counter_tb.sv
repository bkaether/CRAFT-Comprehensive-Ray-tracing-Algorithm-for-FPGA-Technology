`timescale 1ps/1ps

`include "../data_macros.sv"

module ready_valid_counter_tb();

    reg clk;
    reg rst_n;
    reg valid;

    wire ready;

    always #5 clk = ~clk;

    ready_valid_counter #(
        .WIDTH(2),
        .MAX_VAL(3)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .valid(valid),

        .ready(ready)
    );

    initial begin
        clk <= 1;
        rst_n <= 0;
        valid <= 0;
        #20
        rst_n <= 1;
        #50
        valid <= 1;
        #10
        valid <= 0;
        #50
        valid <= 1;
        #200
        $display("Test Finished!");
        $finish();
    end

endmodule