`timescale 1ns/1ps

interface backpressure_intf(input logic clk);

    logic stall;

    clocking mcb @(posedge clk);
        inout stall;
    endclocking

    modport drv(clocking mcb);

endinterface