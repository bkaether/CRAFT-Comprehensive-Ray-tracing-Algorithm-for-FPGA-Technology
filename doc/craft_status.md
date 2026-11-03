# CRAFT status handoff — updated 2026-11-03 (end of session 6)

Supersedes `craft-status-2026-10-27.md`. Covers the `generate_ray` review sessions: reset/macro overhaul, FOV 70°, inferred multiply, first OOC runs, review items #1–#12/#14/#15, lint setup, naming convention, #9 (TEA counter hash), and (session 5) the RTL style conventions, **#7 implemented (`generate_ray_norm`)**, the DSP-input timing fix, the SQ1.16 narrowing, the `_t` sweep, rounding of final trims, **`ray_dir_inverse` (LZC + reciprocal LUT; unit bench passing; OOC timing met)**, and the first combined top **`path_tracer_top` (generate_ray -> ray_dir_inverse), OOC timing met at 3–4% utilization**. Session 6: **`ray_bbox_intersect` RTL review (shift/saturate/sign design)**. Start the next conversation by sharing this doc plus the current versions of the files being worked on.

**Maintenance rule (Brian's request):** update this doc after each review item is completed.

## How Brian wants help on this project
- Design reviews as a senior RTL designer reviewing a junior's work, as educational as possible.
- **One concern at a time**; move on only when Brian says so. Long lists overwhelm.
- Pose questions to think through before giving answers.
- Guidance in English; code only when Brian explicitly asks for it (he has asked for: TEA pseudocode, SV TB models/functions/scoreboards, constraints, assertions, Tcl one-liners, Python generator scripts, doc sections, the path_tracer_top wrapper + OOC xdc).
- **Fixed point:** keep notation minimal and build on Brian's own framing.
- Keep experiment scope small.
- Sessions often run past midnight; when confusion spikes late, suggest stopping.
- Brian is resource-conscious (DSPs especially); show utilization against the 7020's totals (~53,200 LUT, ~106,400 FF, 220 DSP). Reframe latency concerns as throughput vs latency.

## NEXT UP
1. **`ray_dir_inverse` wrap-up:** ASCII fix in the header contract line (`−`/`×` -> `-`/`*`); lint waivers (ASSIGN-6 `abs_dir_*` bit 17; ASSIGN-6 `abs_inv_m_*` low 16 bits); optional input-range assertion (components in [-1, 1] when `us_vld_i`); rerun bench with fixed stimulus (`function void post_randomize()`) and confirm div_by_zero cases (~20 per axis per 400 txns); commit.
2. **`path_tracer_top`:** replace the old `rtl/src/path_tracer_top.sv` with the new one; commit with `constraints/path_tracer_top_ooc.xdc`. TODO in file: move the 3-cycle ray alignment pipe into `ray_dir_inverse` as a USER sideband (like `tea_hash`) so alignment holds by construction (currently matched by constant `INV_DIR_LATENCY = 3`).
3. **`ray_bbox_intersect` unit testbench — START HERE next session.** Before/while writing it: switch the output to `range_t` {min, max} at SQ13.16 (decided); settle miss-output values and behind-the-ray behavior (see section) so the scoreboard knows the intended contract; small cleanups; OOC run.
3b. **BVH traversal FSM** (after the bbox bench): first block Brian implements from scratch rather than rewriting. Questions to work through when designing it (Brian's rough idea was one register holding the highest min / lowest max, enabled on hit, reset to the infinities): (1) in `bvh.inl`, box ranges do NOT accumulate between box tests — each `bbox.hit` starts from (-INF, INF) (lines 259–264); (2) intersecting sibling ranges (e.g. [10, 20] and [30, 40]) gives an empty range; (3) pruning (line 296) compares a box's entry against `closest.distance`, the closest *primitive* hit. -> Which value needs a long-lived register initialized to infinity, and which per-box values only live until that box's decision (traversal stack)?
4. Lint waivers for the `generate_ray` camera_space trim — check whether done.
5. Constants `ONE_Q12_16` / `NEGATIVE_ONE_Q12_16` (actually SQ11.16) — likely unused; grep and delete or rename.
6. Track down "The system cannot find the path specified." in run logs (test a fresh `cmd` window for a stale `AutoRun` registry entry under `Software\Microsoft\Command Processor`; else inspect the run's `runme.bat`).
7. Later: #16 single-source constants; **#13 skid buffers** (stall fanout now 1215, see below); integration bench using `path_tracer_top` as DUT.

## ray_bbox_intersect — design (session 6, 2026-11-02)
- Slab test t = (plane - origin) * 1/d, with 1/d = (-1)^sign * mantissa * 2^shift from `ray_dir_inverse`. **Latency 5.** Output `ds_closest_hit_distance_o` SQ13.16 (30 bits) + `ds_hit_o`.
- Stage 1: per-axis `inside` (origin within slab), `swap = sign & !dbz`, and the subtracts. **Sign applied by swapping the subtraction operands** (sign = 1 -> origin - plane): no negation after the multiply; the swap folds into the subtractor LUTs (~free) and removes a 30-bit carry chain from stage 3. Subtract is SQ12.16 (29 bits), in fabric (too wide for the 25-bit pre-adder; the pre-adder can do D-A but not A-D, so a narrower world would need real muxes in front of the DSP ports).
- Stage 2: multiply alone (`$signed({1'b0, mantissa}) * sub`, SQ1.16 * SQ12.16 = SQ14.32) so it maps into a DSP with its registers. 29 x 18 -> likely 2 DSPs per multiply (12 total); world-size narrowing is the lever if DSPs get tight.
- Stage 3: shift at full width (63-bit target, SQ30.32 — context width sign-extends before `<<`, nothing lost), then **saturate** to SQ13.16 (per-axis t is unbounded for near-parallel rays; final t <= 4096*sqrt(3) ~ 7094 < 2^13). Overflow check = dropped bits [61:45] must all equal sign bit [62]: pos sat `!s[62] && |s[61:45]`, neg sat `s[62] && ~&s[61:45]`; else slice `[45:16]`. Constants `INFINITY_SQ13_16 = 30'h1FFFFFFF`, `NEGATIVE_INFINITY_SQ13_16 = 30'h20000000` (asymmetric is fine: never negated).
- Stage 4: div_by_zero -> (-inf, +inf); min/max swap. Stage 5: lower = max(tmins), upper = min(tmaxs); miss if lower > upper, dbz & !inside on any axis, or both bounds negative.
- Lessons: `<<` drops bits (barrel shifter = the hardware); concatenations are unsigned (zero-extend); `16'b1` is the number 1, not all ones (use `'1` or reduction operators); compare at aligned binary points; reduction operators for "any bit set/clear"; `-x` of the most negative value overflows to itself; `` `default_nettype none `` turns implicit nets from name typos into errors.
- Upper bound is always finite (dominant axis |d| >= 1/sqrt(3)) -> lower == upper == +inf can't occur; optional assertion.
- **Decided:** output both bounds as a `range_t` {min, max} at SQ13.16, matching C++ `times` (the single-distance output was an old I/O-pin workaround from before OOC mode). Caller (`bvh.inl`) passes times = (-INF, INF), so C++ returns raw `lower` (negative when inside) in `times.x`; traversal reads only `[0]` for ordering (line 274) and pruning (line 296). The old "exit distance when inside" output would have pruned boxes containing closer hits. Still to settle: output values on a miss (C++ leaves `times` untouched), and whether to match C++ `true` for boxes entirely behind the ray (HW reports miss) for a bit-accurate scoreboard. Incoming [tmin, tmax] belongs with BVH traversal design.
- **C++ reference bug:** `bvh.inl` line 248 loops over all `primitives` at a leaf instead of `node.start .. node.start + node.size` — fix before using as a traversal reference.
- Remaining: drop unused `inv_dir_sign_*_q1` declarations; stale DSP-absorption comment on the subtract; OOC run (watch stage 5: 3-way min/max + compare + select at 30 bits; stage 3: 63-bit barrel shift + saturation); unit bench.

## path_tracer_top — combined OOC (session 5)
- Chains generate_ray (18) -> ray_dir_inverse (3); **latency 21**. Ports: generate_ray upstream interface; `ds_ray_o` (ray_t, delayed 3 cycles by `ray_pipe` so origin/dir align with the inverse); the 12 inverse outputs; `ds_vld_o`/`ds_stall_i`. Stall is combinational end to end. No timing registers in the real top (registering stall would break the protocol; that's what skid buffers are for).
- `path_tracer_top_ooc.xdc`: 8 ns clock; 2 ns input/output delays via port filters (`DIRECTION == IN && NAME != "clk"`, `DIRECTION == OUT`).
- **Results:** 1,728 LUT (3.25%), 1,105 FF (1.0%), 54 LUTRAM (the ray_pipe direction bits became SRLs; constant origin optimized away), **8 DSP (3.6%)** = 5 (generate_ray) + 3 (inverse). **WNS +0.182 ns**, hold +0.059.
  - **All top-10 paths: `ds_stall_i` -> CE, fanout 1215** (was 795 -> 932 -> 1215 as blocks were added). Port-sourced, so approximate in OOC, but the trend is real.
  - **The generate_ray -> ray_dir_inverse boundary (now reg-to-reg) is not in the top 10** (> +0.224 ns) -> the stage-1 concern from the standalone run (0.177 from an input port with 2 ns input delay) was an OOC artifact; **the stage-1 timing lever is not needed**.
  - Per-module LUT split (inverse 276 LUT here vs 551 standalone) is unreliable after cross-boundary optimization; don't read much into it.

## ray_dir_inverse — design (session 5)
- Old version: 3 parallel Radix-2 Divider Generator IPs, **41-cycle latency**, large.
- **Range reduction:** |d| = m * 2^-k, m in [1, 2) -> 1/|d| = (1/m) * 2^k. Output as a floating-point-style pair (shift applied downstream; 17-bit mantissa fits the DSP 18-bit signed side).
- Stage 1: sign; abs (two's complement conditional negate); trim to Q1.16 (`ABS_DIR_WIDTH = $bits(us_unit_ray_dir_i.x) - 1`); `leading_zero_count` -> k; barrel shift -> m. Stage 2: addr `m[15:8]`, remainder `{8'b0, m[7:0]}`, ROM read. Stage 3: `(diff << 8) * remainder`, `{entry, 16'h8000} - {1'b0, mult}`, trim `[32:16]`. **Latency 3.**
- Outputs: `ds_inv_dir_{mantissa,sign,shift,div_by_zero}_{x,y,z}_o`; contract in header: 1/d = (-1)^sign * mantissa * 2^shift; div_by_zero => mantissa/shift invalid.
- Table: 256 entries, spacing 1/256, max diff 255 at addr 0 (exact limit). Accuracy (exhaustive, rounded): mantissa max 1.10 LSB; 1/|d| relative error max **3.0e-5**. Generator `gen_reciprocal_lut.py`.
- Standalone OOC: 551 LUT, 120 FF, 3 DSP (`(C-(A'*B''))'` per axis — whole stage 3 in one DSP), WNS +0.177 (port-sourced). Vivado moved the stage-1 address register past the ROM for area (BREG/CREG 2 absorption); stage 1 then holds abs -> LZC -> shift -> ROM. Left as is (confirmed fine in the combined run).
- Unit bench passing: relative-error scoreboard (5e-5), reconstructs (-1)^sign * mantissa * 2^shift, separate div_by_zero check; stimulus via per-component case selector `dist` (ZERO/+1/-1/TINY/ANY) + `post_randomize` copy into `unit_vec`.

## Timing levers (apply only if a realistic measurement or the full design shows a path too tight)
- `ray_dir_inverse` stage 1: split `m_q` into address and remainder registers; `(* dont_touch = "true" *)` only on the address register (keeps the ROM in stage 2; remainder still absorbable). Not needed per the combined run.
- Attributes go immediately before the declaration; verify via the DSP report and "trimmed" warnings.
- Slack interpretation: positive slack in a final, fully constrained, routed design = works on hardware (slow corner, worst temp/voltage, clock uncertainty included). Failures come from wrong/missing constraints, CDC, out-of-spec operation. Small slack matters for closure fragility during development. Final verdict = full design with the real clock (PS FCLK).

## Resource-saving options (if resources get tight, or for parallel lanes)
Current total: ~3% LUT, ~4% DSP. Rule: time-multiplex/share only large resources; LUTs plentiful, DSPs scarce.
- Shared reciprocal table (1/3 throughput + backpressure) — only if LUTs tight and BVH rate allows.
- `ray_dir_inverse` interpolation multiplies to LUTs (`use_dsp = "no"`): ~8x8 significant bits; frees 3 DSPs for ~200–300 LUTs.
- Tables in BRAM (dual-port: two lookups/cycle; share between two lanes).
- Norm table range narrowing (~3x smaller, loses FOV flexibility).
- TEA ROUNDS 5 (passed tests; saves ~1/6 of hash, 2 stages); TEA output reuse (four 16-bit numbers per call); two stages/round only for 125 MHz.
- DSP levers: operands within 25x18 signed (17 unsigned on B); narrow struct fields; size world coords so (b - o) ≈ 25 bits (SQ12.12 = ±2048; SQ10.14 = ±512; SQ8.16 = ±128); constants in post-adders; small constant multiplies in LUTs.
- Parallel lanes: stateless TEA -> independent lanes; per-lane resources multiply; skid buffers mandatory.

## Style conventions (in `doc/naming_conventions.md`)
- Fixed-point `Qm.n` / `SQm.n`; format comment on every declaration. Pipeline layout (stages from 1, module-local, banner -> declarations -> logic -> flops; `_d`/`_q`, passthroughs `_qN`; `_pipe` arrays). `logic` internals, `wire` ports; never `logic x = expr;`. Typedefs `_t`, classes not. ASCII-only source. Format constants local, configuration central. Reusable blocks parameterized; fixed-format blocks concrete widths. Round final trims (constant folded into an existing add or the DSP post-adder).

## generate_ray / generate_ray_norm — DONE
- generate_ray latency 18 (12 tea_hash + 2 camera transform + 4 norm). Norm final trims round; accuracy x/y/z max 0.95/0.84/1.17 LSB; |dir|-1 max 2.1e-5. 5 DSPs, no `C' or 0` patch.

## OOC results history (generate_ray alone)
- Pre-TEA +0.397; TEA +0.307; + norm -0.010; + DREG; + SQ1.16 +0.852; + rounding +0.285 (stall-port paths, approximate).
- OOC caveat: Route 35-197/35-198 and Constraints 18-8777 expected; port-sourced slack approximate; reg-to-reg accurate. OOC timing wrapper (registers on all ports, timing-only, never simulated) for realistic stall numbers.

## Vivado simulation sets (lessons)
- Checklist: create empty; add only this bench's files + shared (`tb_pkg`, backpressure pkg/intf); set the set's top immediately; "Include all design sources" on; **Hierarchy Update = Automatic Update and Compile Order** (`set_property source_mgmt_mode All [current_project]`); make active before running.
- "overwriting previous definition of interface" (VRFC 10-3609) = interfaces compiled after the packages whose classes reference them as `virtual` -> fixed by automatic compile order. Interfaces must compile before packages that use them.
- Debug: `<project>.sim/<set>/behav/xsim/` -> `compile.log`, `*_vlog.prj` (plain text; open with Notepad), `compile.bat`; `launch_simulation -scripts_only`; `reset_simulation -simset [current_fileset -simset]`.
- Leftover include path `dv/tb/generate_ray` in the ray_dir_inverse set's `.prj` -> some generate_ray `.svh` still in that set; remove.

## PRNG — #9 CLOSED
Stateless TEA, ROUNDS = 6, latency 12, 0 DSP.

## Lint
Waivers in `scripts/lint_waivers.tcl` (CRAFT lint button). Suppressed: `Synth 8-9661`, `Netlist 29-101`.

## Repo structure
- `rtl/common/pkg/data_structs_pkg.sv`; `rtl/src/{generate_ray,tea_hash,generate_ray_norm,leading_zero_count,ray_dir_inverse,path_tracer_top,ray_bbox_intersect}.sv`; `rtl/mem/{norm_lut,reciprocal_lut}.mem`.
- `scripts/`: `lint.tcl`, `lint_waivers.tcl`, `gen_norm_lut.py`, `gen_reciprocal_lut.py`.
- `constraints/`: per-block OOC xdc files + `path_tracer_top_ooc.xdc`.
- `doc/naming_conventions.md`; `dv/common/tb_pkg.sv`; `dv/tb/generate_ray/`; `dv/tb/ray_dir_inverse/`.
- Older downstream (pre-convention): `ray_inverse_div_wrapper` (obsolete), `ray_bvh_intersect`.

## Testbench
- generate_ray and ray_dir_inverse unit benches passing.
- TODOs: `LATENCY` localparam; error statistics; length check; random seeds; regression grep; generic valid/stall driver class; integration bench on `path_tracer_top`; optional exhaustive sweeps; X-on-invalid-data driving; `ray_bbox_intersect` unit bench (reference = C++ `BBox::hit` semantics, with HW's behind-ray miss).

## Review concerns status
Closed: #1–#12, #14, #15, lint, naming, style sweep, #7, DSP-input fix, SQ1.16 narrowing, `_t` sweep, rounding, combined-top timing check.
In progress: `ray_dir_inverse` wrap-up; `path_tracer_top` commit; `ray_bbox_intersect` (RTL review closed apart from the `range_t` output change and miss/behind-ray contract; unit bench next).
Deferred: #13 stall fanout / skid buffers (fanout 1215, +0.182 approx.).
Open: #16 single-source constants.

## Design policies decided
Lint step 0. Structural pipelining; retiming off. Bracket multiplies with registers. Register data outputs. Trims backed by range proofs and sim assertions; final trims round; values with unbounded intermediate range saturate instead of trimming. 125 MHz. Commit hygiene. Spend DSPs where the work is. Throughput over latency. Fixed point everywhere (floating-style pairs where range demands). ASCII source. Time-multiplex only large resources. Unit benches per block + integration bench. Alignment by construction (sidebands) over matched constants.

## Vivado / reproducibility
Still to do: `.gitignore`; BD rebuild + Tcl export; record Vivado 2023.2.2; project-recreation Tcl (incl. sim sets); seed-regression Tcl. `synth_1`/`impl_1` may still point at the OOC constraint set.
