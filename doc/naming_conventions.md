# CRAFT naming conventions

Conventions for RTL and DV in this repo. When in doubt, follow the rule here; if a rule doesn't fit, change this file rather than making a one-off exception.

## Handshake: valid / stall

- Blocks talk to their neighbors with a valid/stall handshake. A transfer happens on a clock edge where `vld` is high and `stall` is low.
- `stall` is used instead of `ready` (same meaning, opposite polarity: `stall = ~ready`). A block asserts stall to tell upstream to hold while it needs more time.
- The sender holds its data and `vld` stable while stalled.
- AXI-Stream boundaries use `tready`. Convert in the AXI-facing wrapper (one inverter), the same way `aresetn` is converted to `rst`. The inside of the design never uses `ready`.

## Reset

- Synchronous, active-high, named `rst`. No active-low resets inside the design; AXI wrappers convert `aresetn` at the boundary.
- Only control registers (e.g. valid pipes) get a reset. Data registers don't.

## Ports

Every port name has three parts: **interface prefix + name + direction suffix**.

| Part | Values | Meaning |
|---|---|---|
| Interface prefix | `us_`, `ds_` | Which interface the signal belongs to: upstream or downstream |
| Name | `vld`, `stall`, or a data name | What the signal is |
| Direction suffix | `_i`, `_o` | Port direction |

- The prefix applies to **data as well as control**, so it's clear which data travels with which `vld`/`stall` pair (useful when a skid buffer or FIFO is dropped in at a boundary).
- The suffix applies to **every port**. A convention that only covers some ports is worse than none.
- Exception: `clk` and `rst` stay bare.
- Port names describe the module's contract, not its implementation. Never put `_d` / `_q` in a port name.

Port list order: `clk`, `rst`, then the upstream group (data, then control), then the downstream group (data, then control).

Example:

```systemverilog
module generate_ray
    import data_structs_pkg::*;
(
    input  wire       clk,
    input  wire       rst,

    // upstream interface
    // data
    input  wire [9:0] us_pixel_x_i,
    input  wire [9:0] us_pixel_y_i,
    // control
    input  wire       us_vld_i,
    output wire       us_stall_o,

    // downstream interface
    // data
    output ray        ds_ray_o,
    // control
    output wire       ds_vld_o,
    input  wire       ds_stall_i
);
```

The handshake signals for each interface are always:

| Interface | Valid | Stall |
|---|---|---|
| Upstream | `us_vld_i` | `us_stall_o` |
| Downstream | `ds_vld_o` | `ds_stall_i` |

Valid flows with the data; stall flows against it.

## Internal signals

- `_i` / `_o` mark the module boundary only. Internal signals never carry a direction suffix.
- `_d` / `_q` mark the two sides of a flop: `_d` is the next-state value going in, `_q` is the stored value coming out.
  - Use them only on signals that actually form a pair around a flop.
  - Don't create a `_d` alias just to have one. If a port or signal feeds a flop directly with no logic in between, pass it straight into the macro. Create a named `_d` only when real next-state logic sits in front of the flop.
  - Use `_d` (not `_n`) for next-state, since `_n` reads as active-low.
- Purely combinational intermediates (products, comparisons, slices) get plain names with no suffix.
- Data registers are named for the computation that produced them (e.g. `camera_space_x_q`).
- Pure control pipes with no computation are named for their role, keeping the interface prefix (e.g. `ds_vld_q`).
- Output ports are assigned from internal signals. An output driven directly from a `_q` reads as a registered output.

Summary: prefixes say which interface, `_i` / `_o` mark the boundary, `_d` / `_q` mark the inside.

## Abbreviations

Spell words out, except for this closed list:

| Abbreviation | Meaning |
|---|---|
| `clk` | clock |
| `rst` | reset |
| `addr` | address |
| `en` | enable |
| `idx` | index |
| `mult` | multiply / multiplier |
| `vld` | valid |

Structural affixes: `us_`, `ds_`, `_i`, `_o`, `_d`, `_q`, `u_`.

Rules:
- One form per concept across the whole repo. Never both `valid` and `vld`.
- Words not on the list are spelled out (e.g. `stall` stays `stall`).
- To add an abbreviation, test it on its own merits: would an RTL engineer recognize it instantly with zero context? "We already abbreviate similar words" is not a reason. If it passes, add it here first, then use it.

## Instances

- Module and interface instances use a `u_` prefix (e.g. `u_prng_x`, `u_generate_ray_if`), in both RTL and DV, so hierarchies in waveforms and reports read the same way.

## Constants, parameters, and types

- Parameters and localparams are UPPERCASE (e.g. `SCALING_CONST`, `PIXEL_HEIGHT`).
- Types have no `_t` suffix (e.g. `ray`, `point`, `material`). Because of this, a port or signal must never share a name with a type; the `_i` / `_o` suffix rule protects ports from this automatically.

## Comments

- Comments that refer to a constant, parameter, or signal use its exact name (e.g. `PIXEL_HEIGHT - 1`, not `PIXEL_MAX`), so grep finds every reference.
