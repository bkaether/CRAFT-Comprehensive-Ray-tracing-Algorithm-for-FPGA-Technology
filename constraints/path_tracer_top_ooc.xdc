# path_tracer_top_ooc.xdc
# Out-of-context timing constraints for path_tracer_top (synthesis/implementation run with -mode out_of_context).
# Same assumptions as the per-block OOC constraints: 125 MHz clock, 2 ns of the period budgeted outside the block
# on every input and output. Port-sourced/port-sunk paths are approximate in OOC (no HD.PARTPIN_LOCS);
# reg-to-reg paths, including the generate_ray -> ray_dir_inverse boundary, are accurate.

create_clock -period 8.000 -name clk [get_ports clk]

set_input_delay  -clock clk 2.000 [get_ports -filter {DIRECTION == IN && NAME != "clk"}]
set_output_delay -clock clk 2.000 [get_ports -filter {DIRECTION == OUT}]
