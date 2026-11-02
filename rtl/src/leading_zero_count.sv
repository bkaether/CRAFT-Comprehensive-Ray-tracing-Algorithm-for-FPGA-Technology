`timescale 1ns/1ps

module leading_zero_count #(
    parameter int WIDTH
) (
    input wire [WIDTH-1:0] num_i,

    output wire [$clog2(WIDTH+1)-1:0] count_o
);

    logic [$clog2(WIDTH+1)-1:0] count;

    always_comb begin

        count = WIDTH;

        for (int i = 0; i < WIDTH; i++) begin
            if (num_i[i]) begin
                count = WIDTH - 1 - i;
            end
        end
    end

    assign count_o = count;

endmodule