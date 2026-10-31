class generate_ray_scoreboard;
    
    // mailboxes for communication between monitor and scoreboard
    input_mbx_t  input_mbx;
    output_mbx_t output_mbx;

    // testbench parameters passed from the top-level testbench
    real fov_degrees;
    int pixel_width;
    int pixel_height;
    real error_threshold;

    // info owned by the scoreboard
    int err_count;
    int successful_checks;
    
    function new(input_mbx_t input_mbx, output_mbx_t output_mbx, real fov_degrees, int pixel_width, int pixel_height, real error_threshold = 0.001);
        this.input_mbx = input_mbx;
        this.output_mbx = output_mbx;

        this.fov_degrees = fov_degrees;
        this.pixel_width = pixel_width;
        this.pixel_height = pixel_height;
        this.error_threshold = error_threshold;

        err_count = 0;
        successful_checks = 0;
    endfunction

    function void compute_expected(input generate_ray_observed_input observed_input, output real expected_ray_dir_x, output real expected_ray_dir_y, output real expected_ray_dir_z);

        logic [9:0] pixel_x;
        logic [9:0] pixel_y;
        logic [11:0] pixel_sample_idx;
        logic [31:0] hash_key;
        
        logic [31:0] r0;
        logic [31:0] r1;
        real offset_x;
        real offset_y;

        real vert_fov_rad;
        real sensor_plane_height;
        real sensor_plane_width;

        real expected_dir_x;
        real expected_dir_y;
        real expected_dir_z;

        real norm_expected_dir_x;
        real norm_expected_dir_y;
        real norm_expected_dir_z;

        // extract fields from observed input
        pixel_x = observed_input.pixel_x;
        pixel_y = observed_input.pixel_y;
        pixel_sample_idx = observed_input.pixel_sample_idx;

        // get random offsets from hash model
        hash_key = {pixel_x, pixel_y, pixel_sample_idx};
        tea_hash_model(hash_key, PIXEL_SAMPLE_SALT, r0, r1);

        offset_x = fxpt_to_real(r0[31:16], 16);
        offset_y = fxpt_to_real(r1[31:16], 16);

        // calculate sensor plane width and height
        vert_fov_rad = fov_degrees * DEG2RAD;
        sensor_plane_height = 2 * $tan(vert_fov_rad / 2.0); // sensor plane is 1 unit away in Z direction
        sensor_plane_width = (real'(pixel_width) / real'(pixel_height)) * sensor_plane_height;
        
        // calculate camera space x and y
        expected_dir_x = ((real'(pixel_x) + offset_x) / real'(pixel_width) * sensor_plane_width) - (sensor_plane_width / 2);
        expected_dir_y = ((real'(pixel_y) + offset_y) / real'(pixel_height) * sensor_plane_height) - (sensor_plane_height / 2);
        expected_dir_z = -1;

        vec3_normalize(expected_dir_x, expected_dir_y, expected_dir_z, norm_expected_dir_x, norm_expected_dir_y, norm_expected_dir_z);

        // the origin of the ray is always (0, 0, 0), no need to check it at this time
        expected_ray_dir_x = norm_expected_dir_x;
        expected_ray_dir_y = norm_expected_dir_y;
        expected_ray_dir_z = norm_expected_dir_z;

    endfunction

    task report_results();
        $display("Scoreboard Results: %0d successful checks, %0d errors", successful_checks, err_count);
    endtask

    task run();
        forever begin

            generate_ray_observed_input observed_input;

            real expected_output_x;
            real expected_output_y;
            real expected_output_z;

            ray observed_output;

            real observed_output_x;
            real observed_output_y;
            real observed_output_z;

            // get the next input transaction from the mailbox
            input_mbx.get(observed_input);

            // calculate expected output based on observed input
            compute_expected(observed_input, expected_output_x, expected_output_y, expected_output_z);

            // get the next output transaction from the mailbox
            output_mbx.get(observed_output);

            // convert observed normalized dir outputs from fixed point to real for comparison
            observed_output_x = fxpt_to_real(observed_output.dir.x, 16);
            observed_output_y = fxpt_to_real(observed_output.dir.y, 16);
            observed_output_z = fxpt_to_real(observed_output.dir.z, 16);

            // compare expected and observed outputs
            if (is_close_real(expected_output_x, observed_output_x, error_threshold) && 
                is_close_real(expected_output_y, observed_output_y, error_threshold) &&
                is_close_real(expected_output_z, observed_output_z, error_threshold)) begin

                $display("Check passed: expected (%f, %f, %f), got (%f, %f, %f)", expected_output_x, expected_output_y, expected_output_z, observed_output_x, observed_output_y, observed_output_z);
                successful_checks++;
            end else begin
                $error("Mismatch between expected and observed outputs: expected (%f, %f, %f), got (%f, %f, %f)", expected_output_x, expected_output_y, expected_output_z, observed_output_x, observed_output_y, observed_output_z);
                err_count++;
            end
        end
    endtask
endclass