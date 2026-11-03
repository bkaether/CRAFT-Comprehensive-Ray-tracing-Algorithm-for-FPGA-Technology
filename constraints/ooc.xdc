# ooc.xdc
# Generic out-of-context timing constraints for any top module (synthesis/implementation run with -mode out_of_context).
# Requires the clock port to be named clk (naming convention).
#
# 125 MHz clock. I/O delays model the logic outside the block:
#   - Data/control inputs: 1 ns. Every block registers its data outputs, so an input is driven by an upstream flop;
#     the outside budget is clock-to-Q plus routing.
#   - Stall inputs: 2 ns. In the full design stall is a combinational chain through every block with very high
#     fanout, so it arrives late. Stall paths are unreliable in OOC either way; judge them only in integrated runs.
#   - Outputs: 2 ns. Data outputs come straight from flops, so this barely matters; it mainly budgets the
#     combinational ds_stall_i -> us_stall_o passthrough.
#
# Port-sourced/port-sunk paths are approximate in OOC (no HD.PARTPIN_LOCS); reg-to-reg paths are accurate.

create_clock -period 8.000 -name clk [get_ports clk]

set_input_delay  -clock clk 1.000 [get_ports -filter {DIRECTION == IN && NAME != "clk" && NAME !~ "*stall*"}]
set_input_delay  -clock clk 2.000 [get_ports -filter {DIRECTION == IN && NAME =~ "*stall*"}]
set_output_delay -clock clk 2.000 [get_ports -filter {DIRECTION == OUT}]