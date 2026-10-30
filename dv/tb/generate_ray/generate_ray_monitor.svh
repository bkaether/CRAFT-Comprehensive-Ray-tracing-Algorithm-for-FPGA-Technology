class generate_ray_monitor;

    // handle to the interface mon modport for access to passive clocking block (pcb)
    virtual generate_ray_intf.mon vif;

    // mailboxes for sending observed inputs and outputs to the scoreboard
    input_mbx_t  input_mbx;
    output_mbx_t output_mbx;

    // allow testbench to pass in the true interface handle when creating the monitor.
    // interfaces in SystemVerilog must be virtual inside classes
    function new(virtual generate_ray_intf.mon vif, input_mbx_t input_mbx, output_mbx_t output_mbx);
        this.vif = vif;
        this.input_mbx = input_mbx;
        this.output_mbx = output_mbx;
    endfunction

    // monitor inputs to the generate ray module
    task watch_inputs();
        
        forever begin
            // check for a valid pixel at every clock edge
            @(vif.pcb);

            // include reset condition here because a reset in the same cycle as a valid pixel would not make it through the pipeline,
            // and no matching output would be sampled
            if (vif.pcb.us_vld_i && !vif.pcb.us_stall_o && !vif.pcb.rst) begin
                generate_ray_observed_input observed_input;

                // sample valid input
                observed_input.pixel_x = vif.pcb.us_pixel_x_i;
                observed_input.pixel_y = vif.pcb.us_pixel_y_i;
                observed_input.pixel_sample_idx = vif.pcb.us_pixel_sample_idx_i;

                // send to mailbox for the scoreboard
                input_mbx.put(observed_input);
            end
        end

    endtask

    // monitor outputs from the generate ray module
    task watch_outputs();
        
        forever begin
            // check for a valid ray at every clock edge
            @(vif.pcb);

            // don't check for reset here because we want a valid ray during reset to be a bug that is caught.
            // an assertion in the rtl module (or interface) is the right way to catch this unwanted condition
            if (vif.pcb.ds_vld_o && !vif.pcb.ds_stall_i) begin
                // sample valid output
                ray observed_output = vif.pcb.ds_ray_o;

                // send to mailbox for the scoreboard
                output_mbx.put(observed_output);
            end
        end

    endtask

    // start the monitor tasks concurrently
    task run();

        fork
            watch_inputs();
            watch_outputs();
        join_none

    endtask

endclass