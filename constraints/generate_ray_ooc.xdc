# Out-of-context (OOC) timing constraints for generate_ray.
# Used only by the OOC synthesis/implementation runs with generate_ray as top.
# Not for the full system build: there the PL clock comes from the PS.

# 125 MHz clock on the module's clk port
create_clock -name clk -period 8.000 [get_ports clk]

# Model neighboring blocks as using 2 ns of the 8 ns cycle on each side,
# so port-to-flop (e.g. stall_in -> CE pins), flop-to-port, and the
# combinational stall_in -> stall_out passthrough are all timed.
set_input_delay  -clock [get_clocks clk] 2.000 [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_output_delay -clock [get_clocks clk] 2.000 [all_outputs]
