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
- Exception: helper sub-blocks that are only instantiated inside another block (e.g. `tea_hash`) don't face a neighbor, so they omit `us_` / `ds_` and use plain names with `_i` / `_o` (e.g. `vld_i`, `stall_i`, `key_i`). Pipeline-stage blocks that connect to neighboring blocks always use the prefixes.

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
  - Use `_d` (not `_n`) for next-state, since `_n` reads as active-low.
- Purely combinational intermediates (products, comparisons, slices) get plain names with no suffix.
- Data registers are named for the computation that produced them (e.g. `camera_space_x_q`).
- Pure control pipes with no computation are named for their role, keeping the interface prefix (e.g. `ds_vld_q`).
- Output ports are assigned from internal signals. An output driven directly from a `_q` reads as a registered output.

Summary: prefixes say which interface, `_i` / `_o` mark the boundary, `_d` / `_q` mark the inside.

## Fixed-point notation

Every fixed-point signal and constant states its format.

| Notation | Meaning | Total width |
|---|---|---|
| `Qm.n` | unsigned | `m + n` |
| `SQm.n` | signed, sign bit not counted in `m` | `m + n + 1` |

- Plain `Q` always means unsigned. Any signed value must use `SQ`.
- Example: `s_trimmed` is Q2.20 (22 bits); `x_i` is SQ2.16 (19 bits).
- Format comments go on declaration lines, so the declared width can be checked against the format.
- Constant names carry the format in uppercase: `ONE_SQ5_32`, `NEGATIVE_ONE_SQ12_16`.
  
## Generated Pipelines

When a pipeline is built as an array indexed by stage (e.g. in a generate loop), index 0 is usually the combinational input and every later index is a register output. A single `_d` or `_q` suffix can't describe both, so:

- Name the array for what it carries, with a `_pipe` suffix and no `_d`/`_q` (e.g. `hash_pipe_0`, `vld_pipe`).
- Comment the declaration with the index meaning: index 0 is the input, index `i` is the register output of stage `i`.
- Inside the generate loop, the per-stage local wire feeding the flop keeps the `_d` suffix (e.g. `hash_pipe_0_d`), since it really is the next-state value.
- The output port is assigned from the array's last index.

## Manual Pipeline Layout

Multi-stage modules are written top to bottom in the same order the data flows, so reading the file follows the signal path and every register boundary is visible where it occurs.

### Stage numbering
- Stages are numbered from 1. Stage N is the logic that ends at the N-th register boundary.
- Index 0 means the module inputs (zero registers crossed). This matches `_pipe` arrays, where index 0 is the input and index `i` is the output after stage `i`.
- The last stage number is the module's latency. Signals from different stages must never be combined; a stage-3 signal meeting a stage-2 signal is a bug.

### Stage structure
Each stage is one contiguous block, in this order:
1. **Banner comment** naming the stage and what it does, e.g. `// LOGIC STAGE 2 OF 4: LUT read`.
2. **Declarations** for every signal the stage creates: intermediates, the `_d` values, and every flop that ends the stage. Put the fixed-point format on each declaration line (`// SQ2.16`), so the block doubles as the stage's bookkeeping table.
3. **Logic**, as `assign` statements.
4. **Flops** for everything that crosses the stage's boundary, including passthroughs and the valid bit.

### Declarations and types
- Internal signals use `logic`. Ports use `wire`.
- Never declare and assign in one line with a variable type: `logic x = expr;` is a one-time initializer, not continuous logic. Declare on one line, drive with `assign` or a flop macro on another.
- A signal used before the stage that computes it (feedback, or a signal sent back upstream) is declared in a short block at the top of the module, with a comment explaining why.

### Naming across stages
- Values computed in a stage are named for the computation and use plain `_d` / `_q` (`norm_div_trimmed_q`).
- Passthroughs, which keep the same name across several boundaries, use a stage-numbered suffix: `x_q1`, `x_q2`, `x_q3`. The valid pipe follows the same pattern (`vld_q1`, `vld_q2`, …).
- Every signal that continues past a boundary is registered in that stage's flop group, so each stage's flop list is a complete record of what crosses it.

### Repeated stages
- When the stages are identical operations (e.g. hash rounds), use a `_pipe` array and a generate loop instead of hand-written stages. Inside the loop body, keep the same logic → flop order.
- Hand-written stages are for pipelines whose stages each do something different.

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
