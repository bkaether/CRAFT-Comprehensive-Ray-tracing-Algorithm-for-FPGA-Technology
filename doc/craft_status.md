# CRAFT status

Single source of truth for the state of CRAFT (Comprehensive Ray-tracing Algorithm for FPGA Technology): a fixed-point, real-time path tracer on a PYNQ-Z2 (Zynq-7020, xc7z020clg400-1), Vivado 2023.2.2, target 125 MHz. Last updated 2026-11-03.

**Maintenance rule:** update this doc after each completed review item: the NEXT UP list, the module's section, and the review status. Keep module sections current (replace stale facts rather than appending history).

## How Brian wants help on this project
- Design reviews as a senior RTL designer reviewing a junior's work, as educational as possible.
- **One concern at a time**; move on only when Brian says so. Long lists overwhelm.
- Pose questions to think through before giving answers.
- Guidance in English; code only when Brian explicitly asks for it (he has asked for: TEA pseudocode, SV TB models/functions/scoreboards, constraints, assertions, Tcl one-liners, Python generator scripts, doc sections, small wrappers like `path_tracer_top`).
- **Fixed point:** keep notation minimal and build on Brian's own framing.
- Keep experiment scope small.
- Sessions often run past midnight; when confusion spikes late, suggest stopping.
- Resource-conscious (DSPs especially): show utilization against the 7020 totals (~53,200 LUT, ~106,400 FF, 220 DSP). **Throughput over latency**: the goal is room for multiple parallel BVH traversal lanes.

## NEXT UP
1. **`ray_bbox_intersect` rework** (details in its section, "Planned change"): fold the near/far swap into stage 1; round the subtractions conservatively to SQ12.12 so each multiply fits one DSP; move the first min/max level into stage 4. Rerun OOC and compare with the baseline.
2. **`ray_bbox_intersect` unit testbench**: settle the miss-output and behind-the-ray contract first; scoreboard checks containment, not equality.
3. **Move to Claude Code** (VS Code extension): this doc goes in the repo as `doc/craft_status.md`, plus the root `CLAUDE.md`. Consolidate OOC constraints into `constraints/ooc.xdc` and delete the per-block copies.
4. **BVH traversal FSM** design (first block built from scratch; see its section for the open questions).
5. **`ray_dir_inverse` wrap-up** (see its section).
6. **`path_tracer_top`**: commit the new version (replacing the old file).
7. Small cleanups: lint waivers for the `generate_ray` camera_space trim (check whether done); `ONE_Q12_16` / `NEGATIVE_ONE_Q12_16` (actually SQ11.16) likely unused, grep and delete or rename; track down "The system cannot find the path specified." in run logs (try a fresh `cmd` window for a stale `AutoRun` entry under `Software\Microsoft\Command Processor`, else inspect the run's `runme.bat`).
8. Later: single-source constants (see Open design items); skid buffers (see Open design items); integration bench on `path_tracer_top`; a `.claude/skills/new-block-bench/` skill once the bbox bench (third instance) shows which parts are mechanical.

---

## Modules

### generate_ray (with tea_hash, generate_ray_norm) — DONE
- Pixel (x, y, sample index) -> camera ray: origin + unit direction (`ray_t`, direction SQ1.16). **Latency 18** = 12 (tea_hash) + 2 (camera transform) + 4 (norm). FOV 70° vertical, 4:3, 800x600.
- **tea_hash**: stateless TEA counter hash for per-pixel/per-sample jitter (replaced two 16-bit xorshift PRNGs, which had a short period and correlated outputs). ROUNDS = 6, 0 DSP. Deterministic per (pixel, sample), so lanes can run independently.
- **Camera transform**: inferred constant multiply (replaced a vendor multiplier IP whose 26-bit operand didn't fit the DSP); outputs registered.
- **generate_ray_norm**: normalizes the direction so downstream blocks get a unit vector. s = x^2 + y^2 + 1 (SQ3.32 -> trimmed Q2.20), 1/sqrt(s) from a 512-entry table (`rtl/mem/norm_lut.mem`, entry = {Q1.16 value, 8-bit diff}, address `s_trimmed[21:13]`) with linear interpolation, then x, y scaled; z = -1/sqrt(s). Final trims round. Accuracy: x/y/z max 0.95/0.84/1.17 LSB; |dir| - 1 max 2.1e-5. Generator + bit-accurate sweep: `scripts/gen_norm_lut.py`.
- Resources: 5 DSP. OOC history (standalone, stall-port paths, approximate): pre-TEA +0.397, TEA +0.307, + norm -0.010, + DREG fix, + SQ1.16 narrowing +0.852, + rounding +0.285.
- Bench passing (see Verification).

### ray_dir_inverse (with leading_zero_count)
- 1/d per axis via range reduction instead of dividers (old version: 3 Radix-2 divider IPs, 41-cycle latency). |d| = m * 2^-k, m in [1, 2) -> 1/|d| = (1/m) * 2^k. **Latency 3.**
- Output contract: 1/d = (-1)^sign * mantissa * 2^shift; `ds_inv_dir_{mantissa,sign,shift,div_by_zero}_{x,y,z}_o`; mantissa Q1.16 (17 bits, fits the DSP B port); div_by_zero (k == 17) => mantissa/shift invalid.
- Stage 1: sign, abs, trim to Q1.16 (`ABS_DIR_WIDTH`), `leading_zero_count` -> k, barrel shift -> m. Stage 2: address `m[15:8]`, remainder `{8'b0, m[7:0]}`, ROM read. Stage 3: `(diff << 8) * remainder`, `{entry, 16'h8000} - {1'b0, mult}`, trim `[32:16]` (one DSP per axis: `(C-(A'*B''))'`).
- Table: 256 entries, spacing 1/256, max diff 255 (exact limit). Accuracy (exhaustive, rounded): mantissa max 1.10 LSB; relative error max **3.0e-5**. Generator: `scripts/gen_reciprocal_lut.py`.
- Standalone OOC: 551 LUT, 120 FF, 3 DSP, WNS +0.177 (port-sourced, approximate). Vivado moved the stage-1 address register past the ROM for area; confirmed fine in the combined run.
- Bench passing: relative-error scoreboard (5e-5), separate div_by_zero check; stimulus with per-component `dist` (ZERO/+1/-1/TINY/ANY) + `post_randomize` copy into `unit_vec`.
- **Wrap-up to do:** ASCII fix in the header contract line (`−`/`×` -> `-`/`*`); lint waivers (ASSIGN-6 `abs_dir_*` bit 17; `abs_inv_m_*` low 16 bits); optional input-range assertion; rerun bench and confirm div_by_zero cases (~20 per axis per 400 txns); commit. TODO: carry the ray as a USER sideband (like `tea_hash`) so `path_tracer_top` alignment holds by construction.

### ray_bbox_intersect
**Function.** Slab test t = (plane - origin) * 1/d using the `ray_dir_inverse` contract. Inputs: origin (`point_t`, SQ11.16 = ±2048 world), inverse direction fields, box (`bbox_t`), `us_last_times_i` (`range_t`). Outputs: `ds_hit_o`, `ds_times_o` (`range_t`, signed SQ13.16). On hit: intersect [lower, upper] with `last_times`; on miss: pass `last_times` through (matches C++ `BBox::hit`, where `times` is untouched on a miss). **Latency 5.**

**Current design (as of the 2026-11-03 baseline).**
- Stage 1: per-axis `inside`, `swap = sign & !dbz`, subtractions. Sign applied by swapping subtraction operands (sign = 1 -> origin - plane), so no negation after the multiply. Subtraction SQ12.16 (29 bits), in fabric.
- Stage 2: multiply alone, `$signed({1'b0, mantissa}) * sub` (SQ1.16 * SQ12.16 = SQ14.32).
- Stage 3: shift at full width (63-bit target, SQ30.32), then **saturate** to SQ13.16 (per-axis t is unbounded for near-parallel rays; the final t <= 4096*sqrt(3) ~ 7094 < 2^13). Overflow = dropped bits [61:45] differ from sign bit [62]: pos `!s[62] && |s[61:45]`, neg `s[62] && ~&s[61:45]`; else slice `[45:16]`. Infinity constants (`INFINITY_SQ13_16 = 30'h1FFFFFFF`, `NEGATIVE_INFINITY_SQ13_16 = 30'h20000000`) live in `data_structs_pkg`; asymmetric is fine because they are never negated.
- Stage 4: div_by_zero -> (-inf, +inf); min/max swap. Stage 5: lower = max(tmins), upper = min(tmaxs); miss if lower > upper, any axis dbz & !inside, or both bounds negative; then the `last_times` update.
- The upper bound is always finite (dominant axis |d| >= 1/sqrt(3)), so lower == upper == +inf can't occur (optional assertion).

**Baseline OOC (2026-11-03, routed, shared ooc.xdc).** 2,054 LUT (3.86%), 957 FF (0.90%), 38 LUTRAM (the `last_times` passthrough became 60 SRL16), **6 DSP (2.73%)**, **WNS +0.052 ns**.
- DSP: `A'*B'`, A 24 / B 17 bits, AREG = BREG = 1 (stage-1 registers absorbed), **MREG = PREG = 0**. Because the 29-bit subtraction really varies, Vivado split each multiply: DSP on the low 24 bits, the top 5 bits x mantissa plus an adder in fabric (likely about half the LUTs). The product register sits after that adder, so it stays in fabric (Synth 8-3936 trims each to 23 + 24 bits). To confirm: schematic fan-in of a `mult_result_*_q` flop (CARRY4 between DSP P and the flops).
- Timing: all top-10 paths reg-to-reg in stage 5, `tmin_y_q` -> `time_lower_q`/`time_upper_q`, 13 levels, logic 3.6 / net 4.3 ns, fo=30 on the lower-bound select (three 30-bit carry chains in series).

**Planned change (decided 2026-11-03).**
1. Fold the swap into stage 1 as near/far subtractions: near = sign ? (o - max) : (min - o); far = sign ? (o - min) : (max - o). Same six subtractors; removes the stage-4 swap muxes (~180 LUT) and the swap flops.
2. Round each subtraction **conservatively** to SQ12.12 (25 bits, fits the A port -> one DSP per multiply, product register absorbable): near rounds down (drop 4 LSBs, free), far rounds up (add 0xF LSBs before dropping, folded into the subtractor). The box can only grow: the cost is extra traversal, never a false miss. (The origin can't be rounded, so rounding the box corners alone wouldn't shrink the subtraction.)
3. With the swap gone, move the first min/max level (and possibly more of stage 5) into stage 4.
4. Decide whether the far bound needs an extra small margin: the product trim truncates (rounds the far t down) and the reciprocal has ~3e-5 relative error.
- Expected after: A 25 bits with MREG/PREG set, LUTs down noticeably, stage-5 paths out of the top 10. Watch stage 3 (63-bit shift + saturation) next.

**Testbench contract to settle.** Reference = C++ `BBox::hit` called with times = (-INF, INF). Known intended differences: HW reports a miss for boxes entirely behind the ray (C++ returns true with both bounds negative); per-axis t saturates at ±2^13; conservative rounding. The scoreboard checks containment (HW range contains the exact range; HW hits whenever the exact test hits), not equality. Decide the expected `ds_times_o` on a miss.

**Lessons from this review.** `<<` drops bits (a barrel shifter is the hardware); the left operand of `<<` takes the context width; concatenations are unsigned (zero-extend); `16'b1` is the number 1, not all ones (use `'1` or reduction operators); compare at aligned binary points; reduction operators for "any bit set/clear"; `-x` of the most negative value overflows to itself; `` `default_nettype none `` turns implicit nets from name typos into errors.

### path_tracer_top
- Chains generate_ray (18) -> ray_dir_inverse (3); **latency 21**. `ds_ray_o` is delayed 3 cycles by `ray_pipe` (constant `INV_DIR_LATENCY = 3`) to align with the inverse outputs; to be replaced by the USER sideband. Stall is combinational end to end; no timing registers in the real top.
- OOC (session 5, old 2 ns input delay): 1,728 LUT (3.25%), 1,105 FF (1.0%), 54 LUTRAM, **8 DSP (3.6%)** = 5 + 3. **WNS +0.182 ns**, hold +0.059. All top-10 paths: `ds_stall_i` -> CE, fanout 1215 (795 -> 932 -> 1215 as blocks were added). The generate_ray -> ray_dir_inverse boundary (reg-to-reg) is not in the top 10.
- Next: add `ray_bbox_intersect` once reworked; keep integrating blocks here as the honest timing check.

### BVH traversal FSM (planned)
- First block designed from scratch. Reference: `bvh.inl` `BVH::hit`.
- How the C++ uses box tests: every `bbox.hit` starts from times = (-INF, INF) (lines 259–264); children are visited nearest-entry first (line 274); the second child is skipped when its entry >= `closest.distance`, the closest *primitive* hit so far (line 296). `times.y` is never used.
- Questions to work through: box ranges don't accumulate between box tests, and intersecting sibling ranges (e.g. [10, 20] and [30, 40]) gives an empty range. Which value needs a long-lived register initialized to infinity, and which per-box values only live until that box's decision (traversal stack)?
- **C++ reference bug:** `bvh.inl` line 248 loops over all `primitives` at a leaf instead of `node.start .. node.start + node.size` (correct image, no BVH speedup). Fix before using it as a reference.
- Node storage idea: whole-number box corners (min floored, max ceiled) as a compact node format; boxes only grow.

---

## Verification
- **Architecture** (plain SystemVerilog, not UVM; same structure and function/task names per bench, renamed per DUT): interface with clocking blocks (driver `mcb`, passive `pcb`; modports `drv`/`mon`); classes: input transaction, driver, monitor (forked input/output tasks), scoreboard (real-domain comparison with tolerance, counters, `report_results`); reusable backpressure component (`dv/common/backpressure/`, modes NONE/RAND/BURST, `wait_stall_done()`).
- Driver: drive, wait one edge, wait while `vld && stall`, return once accepted (no trailing wait). Monitor: input accepted on `vld && !stall_o`; output transfer on `ds_vld && !ds_stall`. Drain: backpressure NONE -> stop -> `wait_stall_done()` -> wait the pipeline latency.
- Status: generate_ray and ray_dir_inverse unit benches passing; ray_bbox_intersect next.
- TODOs: `LATENCY` localparam; check mailboxes empty before reporting; error statistics; random seeds and a seed-regression Tcl; timeout watchdog; generic valid/stall driver class; X on invalid data; integration bench on `path_tracer_top`; optional exhaustive sweeps.
- **Simulation sets (lessons):** create empty; add only this bench's files plus shared (`tb_pkg`, backpressure pkg/intf); set the top immediately; "Include all design sources" on; Hierarchy Update = Automatic Update and Compile Order (`set_property source_mgmt_mode All [current_project]`); make active before running. Include paths aren't recursive. VRFC 10-3609 "overwriting previous definition of interface" = interfaces compiled after packages that use them (fixed by automatic compile order). Debug in `<project>.sim/<set>/behav/xsim/` (`compile.log`, `*_vlog.prj`, `compile.bat`); `launch_simulation -scripts_only`; `reset_simulation -simset [current_fileset -simset]`. Leftover generate_ray `.svh` in the ray_dir_inverse set: remove.

## OOC flow
- Shared `constraints/ooc.xdc`: 8 ns `clk`; data/control inputs 1 ns (driven by upstream flops); stall inputs 2 ns; outputs 2 ns. Port filters make it work for any block whose clock port is `clk`. Add a small per-block file only if a block needs extra constraints.
- Caveats: Route 35-197/35-198 and Constraints 18-8777 expected; port-sourced/port-sunk paths approximate (no partition pins); reg-to-reg accurate. Stall paths are only meaningful in integrated runs. Optional OOC timing wrapper (registers on all ports, timing-only) for realistic stall numbers.
- Report checklist: utilization vs 7020 totals, DSP report (mapping, A/B sizes, which REGs absorbed), "trimmed" warnings, top paths by stage.
- Possible later: a batch Tcl script (`vivado -mode batch`) that loops over blocks and writes reports to `reports/<block>/`, leaving the project's top untouched.

## Timing levers (only when a realistic measurement shows a path too tight)
- Rebalance logic between stages before adding one; adding a stage changes latencies others depend on (prefer alignment by sideband).
- `ray_dir_inverse` stage 1: split `m_q` into address and remainder registers; `(* dont_touch = "true" *)` only on the address register. Not needed per the combined run.
- Attributes go immediately before the declaration; verify via the DSP report and "trimmed" warnings.
- Slack: positive slack in a final, fully constrained, routed design = works on hardware (slow corner, worst temp/voltage, clock uncertainty included). Final verdict = full design with the real clock (PS FCLK).

## Resource-saving options (if resources get tight, or for parallel lanes)
Rule: time-multiplex/share only large resources; LUTs plentiful, DSPs scarce; per-lane resources multiply.
- DSP fit: operands within 25 x 18 signed (17 unsigned on B); narrow struct fields; subtraction into a multiply <= 25 bits (conservative rounding, as planned in ray_bbox_intersect); constants in post-adders; small constant multiplies in LUTs.
- Shared reciprocal table (1/3 throughput + backpressure), only if LUTs are tight and the BVH rate allows.
- `ray_dir_inverse` interpolation multiplies in LUTs (`use_dsp = "no"`): frees 3 DSPs for ~200–300 LUTs.
- Tables in BRAM (dual-port: two lookups/cycle, share between two lanes).
- Norm table range narrowing (~3x smaller, loses FOV flexibility).
- TEA ROUNDS 5 (passed tests; saves ~1/6 of the hash and 2 stages); reuse TEA output (four 16-bit numbers per call).
- Parallel lanes: stateless TEA -> independent lanes; skid buffers mandatory.

## Design policies and style
- Policies: lint as step 0; structural pipelining, retiming off; bracket multiplies with registers; write arithmetic in the shape of the DSP48E1; register data outputs; trims backed by range proofs and sim assertions; final trims round; values with unbounded range saturate; conservative rounding where a test only culls; 125 MHz; fixed point everywhere (floating-style pairs where range demands); time-multiplex only large resources; unit bench per block plus an integration bench; alignment by construction over matched constants; commit hygiene.
- Handshake: valid/stall; stall is a combinational passthrough; every pipeline enable is `~ds_stall_i`. Sync active-high reset on control (valid) only. Macros in `rtl/common/include/ff_macros.svh`: `FFLNR` (data), `FFLSR` (control).
- Style (full detail in `doc/naming_conventions.md`): `Qm.n` unsigned / `SQm.n` signed (sign bit not counted), format comment on every declaration; per stage: banner, declarations, assigns, flops; stages numbered from 1, module-local; `_d`/`_q`, passthroughs `_qN`, `_pipe` arrays, `u_` instances, typedefs `_t`; `logic` internally, `wire` on ports; never `logic x = expr;`; ASCII-only source; format constants local, configuration central; reusable blocks parameterized.

## Lint
Waivers in `scripts/lint_waivers.tcl` (CRAFT lint button). Suppressed: `Synth 8-9661`, `Netlist 29-101`.

## Repo structure
- `rtl/common/pkg/data_structs_pkg.sv` (types incl. `point_t` SQ11.16, `bbox_t`, `range_t`, `ray_t`; infinity constants; `material` enum, 8-bit); `rtl/common/include/ff_macros.svh`.
- `rtl/src/`: `generate_ray`, `tea_hash`, `generate_ray_norm`, `leading_zero_count`, `ray_dir_inverse`, `ray_bbox_intersect`, `path_tracer_top`. Older, pre-convention: `ray_inverse_div_wrapper` (obsolete), `ray_bvh_intersect` (WIP; must compile or be excluded for sims).
- `rtl/mem/`: `norm_lut.mem`, `reciprocal_lut.mem` (generated; don't hand-edit).
- `dv/common/tb_pkg.sv` (`fxpt_to_real`, `is_close_real`, ...); `dv/common/backpressure/`; `dv/tb/generate_ray/`, `dv/tb/ray_dir_inverse/`.
- `scripts/`: `lint.tcl`, `lint_waivers.tcl`, `gen_norm_lut.py`, `gen_reciprocal_lut.py` (find the repo root via `.git`).
- `constraints/`: `ooc.xdc` (shared). `doc/`: `naming_conventions.md`, `craft_status.md`. Root `CLAUDE.md`.
- The Vivado project lives outside the repo; sources and IP are referenced in place. `ip/` (`.xci` only), `bd/` (early, to be rebuilt), `utilization/` (kept as records).

## Vivado / reproducibility (to do)
`.gitignore` (Vivado patterns; in `ip/*/` ignore everything except `.xci`; `.claude/settings.local.json`); BD rebuild + Tcl export; record Vivado 2023.2.2; project-recreation Tcl (sources, include dirs, IP, BD, sim sets, tops); seed-regression Tcl; check whether `synth_1`/`impl_1` still point at the OOC constraint set.

## Open design items
- **Skid buffers / stall fanout (deferred).** Stall is a combinational passthrough, so one `ds_stall_i` drives every pipeline enable in the chain: fanout 1,215 in `path_tracer_top` and growing with each block. Skid buffers between blocks break the chain; mandatory before parallel lanes. Judge only in integrated runs.
- **Single-source constants (partially done).** Constants derived by hand (camera/FOV shifts and scales, table contents, format constants) should come from one source shared with the C++ model and the generator scripts. Done so far: infinity constants moved to `data_structs_pkg`; LUTs generated by scripts.

## Review history
- Done: `generate_ray` full review (FOV corrected to 70°, latency and valid/stall protocol, packages/macros/includes, image orientation, fixed-point comments, scale-constant precision, explicit signedness, direction normalization, PRNG replaced by TEA, registered outputs, inferred multiply); lint setup; naming convention and style sweep; DSP-input timing fix; SQ1.16 narrowing; `_t` sweep; rounding of final trims; `ray_dir_inverse` design; combined-top timing check; `ray_bbox_intersect` RTL review (shift/saturate/sign, `range_t` output).
- In progress: `ray_bbox_intersect` rework + bench; `ray_dir_inverse` wrap-up; `path_tracer_top` commit.
