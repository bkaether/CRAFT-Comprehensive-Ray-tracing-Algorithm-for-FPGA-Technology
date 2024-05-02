`timescale 1ns/1ps

`include "../data_macros.sv"

module ready_valid_counter_tb();

    reg clk;
    reg rst_n;
    reg go;

    wire done;

    always #4 clk = ~clk;

    ready_valid_counter #(
        .WIDTH(2),
        .MAX_VAL(3)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .go(go),

        .done(done)
    );

    initial begin
        clk <= 1;
        rst_n <= 0;
        go <= 0;
        #16
        rst_n <= 1;
        #40
        go <= 1;
        #8
        go <= 0;
        #40
        go <= 1;
        #160
        $display("Test Finished!");
        $finish();
    end

endmodule