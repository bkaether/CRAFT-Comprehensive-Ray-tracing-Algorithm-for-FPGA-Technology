`timescale 1ps/1ps

module xor_prng_tb();

    parameter CYCLES = 1000000;

    reg clk;
    reg rst_n;

    wire [11:0] rand_num;

    integer i;
    reg [63:0] sum;  // Sum variable to avoid overflow with large CYCLES
    real average;    // For storing the average value

    always #5 clk = ~clk;

    xor_prng DUT (
        .clk(clk),
        .rst_n(rst_n),

        .rand_num(rand_num)
    );

    initial begin
        clk <= 0;
        rst_n <= 0;
        sum <= 0;
        #20
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