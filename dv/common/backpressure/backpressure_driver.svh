`timescale 1ns/1ps

class backpressure_driver;

    virtual backpressure_intf.drv vif;

    backpressure_mode mode;
    int rand_stall_prob;
    int burst_length;
    int burst_stall_prob;

    function new(virtual backpressure_intf.drv vif, int rand_stall_prob = 2, int burst_length = 5, int burst_stall_prob = 8);
        this.vif = vif;

        this.mode = NONE;
        this.rand_stall_prob = rand_stall_prob;
        this.burst_length = burst_length;
        this.burst_stall_prob = burst_stall_prob;
    endfunction

    task drive_burst_stall();
        vif.mcb.stall <= 1;
        repeat (burst_length) @(vif.mcb);
    endtask

    task wait_stall_done();
        // Wait for a clocking event where the sampled stall is low.
        // If a burst is still in progress, this keeps waiting until it ends.
        @(vif.mcb iff (!vif.mcb.stall));
    endtask

    task run();

        // initial align with clock edge
        @(vif.mcb);

        forever begin
            
            case (mode)
                NONE: begin
                    vif.mcb.stall <= 0;
                    @(vif.mcb);
                end

                RAND: begin
                    vif.mcb.stall <= $urandom_range(rand_stall_prob-1);
                    @(vif.mcb);
                end

                BURST: begin
                    int send_burst_stall;
                    send_burst_stall = $urandom_range(burst_stall_prob-1);
                    if (send_burst_stall == 0) begin
                        drive_burst_stall();
                    end else begin
                        vif.mcb.stall <= 0;
                        @(vif.mcb);
                    end
                    
                end

                default: begin
                    vif.mcb.stall <= 0;
                    @(vif.mcb);
                end
            endcase

        end

    endtask

endclass