`timescale 1ps/1ps

`include "../data_macros.sv"

module ready_valid_counter_tb();

    reg clk;
    reg rst_n;
    reg go;

    wire done;

    always #5 clk = ~clk;

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
        #20
        rst_n <= 1;
        #50
        go <= 1;
        #10
        go <= 0;
        #50
        go <= 1;
        #200
        $display("Test Finished!");
        $finish();
    end

endmodule