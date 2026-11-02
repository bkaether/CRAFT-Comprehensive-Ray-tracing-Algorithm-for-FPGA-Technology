class ray_dir_inverse_scoreboard;

    // mailboxes for communication between monitor and scoreboard
    input_mbx_t  input_mbx;
    output_mbx_t output_mbx;

    // testbench parameters passed from the top-level testbench
    // the inverse spans [1, 2^16], so an absolute threshold is meaningless; checks use RELATIVE error.
    // gen_reciprocal_lut.py measured a worst case of 3.0e-5 relative error over every possible input.
    real rel_error_threshold;

    // info owned by the scoreboard
    int err_count;
    int successful_checks;

    function new(input_mbx_t input_mbx, output_mbx_t output_mbx, real rel_error_threshold = 5.0e-5);
        this.input_mbx = input_mbx;
        this.output_mbx = output_mbx;

        this.rel_error_threshold = rel_error_threshold;

        err_count = 0;
        successful_checks = 0;
    endfunction

    // relative closeness for values that span many orders of magnitude
    function bit is_close_relative(real expected, real observed, real threshold);
        real diff;

        diff = (observed > expected) ? (observed - expected) : (expected - observed);

        return diff <= (threshold * ((expected < 0.0) ? -expected : expected));
    endfunction

    function void compute_expected(input unit_vec3_t observed_input,
                                   output real expected_inv_dir_x, output real expected_inv_dir_y, output real expected_inv_dir_z,
                                   output bit  expected_div_by_zero_x, output bit expected_div_by_zero_y, output bit expected_div_by_zero_z);

        real dir_x;
        real dir_y;
        real dir_z;

        // convert the SQ1.16 input direction components to real
        dir_x = fxpt_to_real(observed_input.x, 16);
        dir_y = fxpt_to_real(observed_input.y, 16);
        dir_z = fxpt_to_real(observed_input.z, 16);

        // a zero component has no inverse; the DUT must flag it instead of producing a value
        expected_div_by_zero_x = (dir_x == 0.0);
        expected_div_by_zero_y = (dir_y == 0.0);
        expected_div_by_zero_z = (dir_z == 0.0);

        // exact inverse of the quantized input (value is unused when the component is zero)
        expected_inv_dir_x = expected_div_by_zero_x ? 0.0 : (1.0 / dir_x);
        expected_inv_dir_y = expected_div_by_zero_y ? 0.0 : (1.0 / dir_y);
        expected_inv_dir_z = expected_div_by_zero_z ? 0.0 : (1.0 / dir_z);

    endfunction

    // reconstruct 1/d from the DUT's output contract: 1/d = (-1)^sign * mantissa * 2^shift (mantissa is unsigned Q1.16)
    function real reconstruct_inverse(logic [16:0] mantissa, logic sign, logic [4:0] shift);
        real magnitude;

        magnitude = fxpt_to_real(mantissa, 16) * (2.0 ** shift);

        return sign ? -magnitude : magnitude;
    endfunction

    // one component passes if the div_by_zero flag matches and, for nonzero inputs, the value is within the relative threshold
    function bit check_component(real expected, bit expected_div_by_zero, real observed, logic observed_div_by_zero);
        if (observed_div_by_zero !== expected_div_by_zero) begin
            return 1'b0;
        end

        if (expected_div_by_zero) begin
            return 1'b1;    // mantissa, sign, and shift are don't-cares when the flag is set
        end

        return is_close_relative(expected, observed, rel_error_threshold);
    endfunction

    task report_results();
        $display("Scoreboard Results: %0d successful checks, %0d errors", successful_checks, err_count);
    endtask

    task run();
        forever begin

            unit_vec3_t observed_input;

            real expected_output_x;
            real expected_output_y;
            real expected_output_z;

            bit expected_div_by_zero_x;
            bit expected_div_by_zero_y;
            bit expected_div_by_zero_z;

            ray_dir_inverse_observed_output_t observed_output;

            real observed_output_x;
            real observed_output_y;
            real observed_output_z;

            // get the next input transaction from the mailbox
            input_mbx.get(observed_input);

            // calculate expected output based on observed input
            compute_expected(observed_input, expected_output_x, expected_output_y, expected_output_z,
                             expected_div_by_zero_x, expected_div_by_zero_y, expected_div_by_zero_z);

            // get the next output transaction from the mailbox
            output_mbx.get(observed_output);

            // convert observed {mantissa, sign, shift} outputs to real for comparison
            observed_output_x = reconstruct_inverse(observed_output.mantissa_x, observed_output.sign_x, observed_output.shift_x);
            observed_output_y = reconstruct_inverse(observed_output.mantissa_y, observed_output.sign_y, observed_output.shift_y);
            observed_output_z = reconstruct_inverse(observed_output.mantissa_z, observed_output.sign_z, observed_output.shift_z);

            // compare expected and observed outputs
            if (check_component(expected_output_x, expected_div_by_zero_x, observed_output_x, observed_output.div_by_zero_x) &&
                check_component(expected_output_y, expected_div_by_zero_y, observed_output_y, observed_output.div_by_zero_y) &&
                check_component(expected_output_z, expected_div_by_zero_z, observed_output_z, observed_output.div_by_zero_z)) begin

                $display("Check passed: expected (%f, %f, %f) dbz (%0b, %0b, %0b), got (%f, %f, %f) dbz (%0b, %0b, %0b)",
                         expected_output_x, expected_output_y, expected_output_z,
                         expected_div_by_zero_x, expected_div_by_zero_y, expected_div_by_zero_z,
                         observed_output_x, observed_output_y, observed_output_z,
                         observed_output.div_by_zero_x, observed_output.div_by_zero_y, observed_output.div_by_zero_z);
                successful_checks++;
            end else begin
                $error("Mismatch between expected and observed outputs: expected (%f, %f, %f) dbz (%0b, %0b, %0b), got (%f, %f, %f) dbz (%0b, %0b, %0b)",
                       expected_output_x, expected_output_y, expected_output_z,
                       expected_div_by_zero_x, expected_div_by_zero_y, expected_div_by_zero_z,
                       observed_output_x, observed_output_y, observed_output_z,
                       observed_output.div_by_zero_x, observed_output.div_by_zero_y, observed_output.div_by_zero_z);
                err_count++;
            end
        end
    endtask
endclass
