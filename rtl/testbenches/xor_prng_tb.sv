`timescale 1ns/1ps

module xor_prng_tb();

    parameter CYCLES = 100000;

    reg clk;
    reg rst_n;
    reg enable;

    wire [15:0] rand_num;

    integer i;
    reg [63:0] sum;  // Sum variable to avoid overflow with large CYCLES
    real average;    // For storing the average value

    always #4 clk = ~clk;

    xor_prng #(
        .SEED(16'h5A3C)
//        .SEED(16'hC0DE)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),

        .rand_num(rand_num)
    );

    initial begin
        clk <= 0;
        rst_n <= 0;
        sum <= 0;
        enable <= 1;
        #16
        rst_n <= 1;

        for (i = 0; i < CYCLES; i++) begin
            @(posedge clk);
            sum = sum + rand_num;
        end
        
        // Calculate average
        average = real'(sum) / CYCLES;

        // Display results
        $display("Total Sum: %d", sum);
        $display("Average Value: %f", average);


        $display("Test Finished");
        $finish();
    end

endmodule