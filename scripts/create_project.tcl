# create_project.tcl - rebuild the CRAFT Vivado project from a clean repo clone.
#
# Recreates: part + PYNQ-Z2 board part, design sources (rtl/), include dirs, constraint sets
# (constrs_1 = board xdc, ooc = constraints/ooc.xdc), one simulation set per bench folder in
# dv/tb/<block>/ (named <block>_sim, top tb_<block>), the per-block OOC synth/impl runs, message
# suppressions, and the lint toolbar button (GUI only).
# Sources are referenced in place (nothing is copied into the project), so repo edits show up live.
#
# Usage (Vivado 2023.2):
#   batch:   vivado -mode batch -source <repo>/scripts/create_project.tcl [-tclargs -dir <path> -force]
#   console: source <repo>/scripts/create_project.tcl   (project stays open; set craft_proj_dir /
#            craft_force before sourcing to override the defaults)
#
# Default project location: a folder named CRAFT next to the repo clone (outside the repo).
# -force overwrites an existing project in that folder.

# ---------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------
set proj_name      CRAFT
set part           xc7z020clg400-1
set board_part     tul.com.tw:pynq-z2:part0:1.0
set synth_top      path_tracer_top
set active_simset  ray_dir_inverse_sim
set ooc_blocks     {generate_ray ray_dir_inverse path_tracer_top ray_bbox_intersect}
set sim_runtime    5ms

set repo [file normalize [file join [file dirname [info script]] ..]]

# ---------------------------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------------------------
if {![info exists craft_proj_dir]} { set craft_proj_dir [file join [file dirname $repo] $proj_name] }
if {![info exists craft_force]}    { set craft_force 0 }

if {[info exists ::argv]} {
  for {set i 0} {$i < [llength $::argv]} {incr i} {
    switch -- [lindex $::argv $i] {
      -dir    { incr i; set craft_proj_dir [lindex $::argv $i] }
      -force  { set craft_force 1 }
      default { error "create_project.tcl: unknown argument '[lindex $::argv $i]' (use -dir <path>, -force)" }
    }
  }
}
set proj_dir [file normalize $craft_proj_dir]

if {$proj_dir eq $repo} {
  error "create_project.tcl: refusing to create the project in the repo root ($repo)"
}
if {[file exists [file join $proj_dir $proj_name.xpr]] && !$craft_force} {
  error "create_project.tcl: $proj_dir/$proj_name.xpr already exists; pass -force (or set craft_force 1) to overwrite"
}

puts "INFO: \[CRAFT\] repo    = $repo"
puts "INFO: \[CRAFT\] project = $proj_dir/$proj_name.xpr"

proc repo_glob {repo pattern} {
  return [lsort [glob -nocomplain -directory $repo -- $pattern]]
}

# ---------------------------------------------------------------------------------------------
# Board files (before the project exists, so get_board_parts searches the session repo paths)
# The PYNQ-Z2 board files come from the Xilinx board store (XHub). Point Vivado at the local
# store, and install from the internet if the board is missing. Not fatal: only the board xdc
# presets / block design need it; RTL, sims and OOC runs work with the bare part.
# ---------------------------------------------------------------------------------------------
set board_ok  0
set store_dir ""
if {[catch {
  set store     [xhub::get_xstores xilinx_board_store]
  set store_dir [get_property LOCAL_ROOT_DIR $store]
  if {[file isdirectory $store_dir]} { set_param board.repoPaths [list $store_dir] }
  if {[llength [get_board_parts -quiet $board_part]] == 0} {
    puts "INFO: \[CRAFT\] $board_part not installed; installing from the Xilinx board store..."
    xhub::refresh_catalog $store
    set items [xhub::get_xitems -of_objects $store *:pynq-z2:*]
    if {[llength $items] > 0} { xhub::install [lindex $items 0] }
    set_param board.repoPaths [list $store_dir]
  }
  set board_ok [expr {[llength [get_board_parts -quiet $board_part]] > 0}]
} err]} {
  puts "WARNING: \[CRAFT\] board store access failed: $err"
}

# ---------------------------------------------------------------------------------------------
# Project
# ---------------------------------------------------------------------------------------------
if {$craft_force} {
  create_project $proj_name $proj_dir -part $part -force
} else {
  create_project $proj_name $proj_dir -part $part
}
set proj [current_project]

if {$board_ok} {
  set_property board_part_repo_paths [list $store_dir] $proj
  set_property board_part $board_part $proj
} else {
  puts "WARNING: \[CRAFT\] board part $board_part not available; project uses part $part only."
  puts "WARNING: \[CRAFT\] Fix: Tools > Vivado Store > Boards > install PYNQ-Z2, then"
  puts "WARNING: \[CRAFT\]      set_property board_part $board_part \[current_project\]"
}

set_property default_lib       xil_defaultlib $proj
set_property target_language   Verilog        $proj
set_property simulator_language Mixed         $proj
set_property source_mgmt_mode  All            $proj

# ---------------------------------------------------------------------------------------------
# Design sources (sources_1)
# ---------------------------------------------------------------------------------------------
set src_fs [get_filesets sources_1]
set rtl_files [concat \
  [repo_glob $repo rtl/common/pkg/*.sv] \
  [repo_glob $repo rtl/src/*.sv] \
  [repo_glob $repo rtl/mem/*.mem]]
add_files -norecurse -fileset $src_fs $rtl_files
set_property include_dirs [list [file join $repo rtl/common/include]] $src_fs
set_property top $synth_top $src_fs

# ---------------------------------------------------------------------------------------------
# Constraints: constrs_1 (board, used by synth_1/impl_1) and ooc (shared OOC constraints)
# ---------------------------------------------------------------------------------------------
add_files -norecurse -fileset [get_filesets constrs_1] [list [file join $repo "constraints/PYNQ-Z2 v1.0.xdc"]]

create_fileset -constrset ooc
add_files -norecurse -fileset [get_filesets ooc] [list [file join $repo constraints/ooc.xdc]]

# ---------------------------------------------------------------------------------------------
# Simulation sets: one per dv/tb/<block>/ folder, named <block>_sim, top tb_<block>.
# Each set holds only its own bench .sv files plus the shared DV files; .svh files are reached
# through include dirs. Design sources come in via SOURCE_SET = sources_1 ("Include all design
# sources"), and source_mgmt_mode All gives automatic compile order (interfaces before packages).
# ---------------------------------------------------------------------------------------------
set dv_shared [concat \
  [list [file join $repo dv/common/tb_pkg.sv]] \
  [repo_glob $repo dv/common/backpressure/*.sv]]

set simsets {}
foreach bench_dir [repo_glob $repo dv/tb/*] {
  if {![file isdirectory $bench_dir]} { continue }
  set block [file tail $bench_dir]
  set bench_files [lsort [glob -nocomplain -directory $bench_dir *.sv]]
  if {[llength $bench_files] == 0} { continue }

  set fs_name ${block}_sim
  create_fileset -simset $fs_name
  set fs [get_filesets $fs_name]
  add_files -norecurse -fileset $fs [concat $dv_shared $bench_files]
  set_property include_dirs [list \
    $bench_dir \
    [file join $repo rtl/common/include] \
    [file join $repo dv/common/backpressure]] $fs
  set_property source_set  sources_1      $fs
  set_property top         tb_$block      $fs
  set_property top_lib     xil_defaultlib $fs
  set_property -name xsim.simulate.runtime -value $sim_runtime -objects $fs
  lappend simsets $fs_name
  puts "INFO: \[CRAFT\] simset $fs_name: [llength $bench_files] bench file(s), top tb_$block"
}

# Make the chosen simset active (fall back to the first one), then drop the default sim_1.
if {[lsearch -exact $simsets $active_simset] < 0 && [llength $simsets] > 0} {
  set active_simset [lindex $simsets 0]
}
if {[llength $simsets] > 0} {
  current_fileset -simset [get_filesets $active_simset]
  if {[llength [get_filesets -quiet sim_1]] > 0} { delete_fileset [get_filesets sim_1] }
}

# ---------------------------------------------------------------------------------------------
# Runs: synth_1/impl_1 (constrs_1, created by create_project) plus per-block OOC runs on the
# ooc constraint set. The OOC runs synthesize the sources_1 top, so set the top before launching.
# ---------------------------------------------------------------------------------------------
foreach block $ooc_blocks {
  create_run ${block}_synth -part $part -constrset ooc \
    -flow {Vivado Synthesis 2023} -strategy {Vivado Synthesis Defaults}
  set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} \
    -objects [get_runs ${block}_synth]
  create_run ${block}_impl -part $part -constrset ooc -parent_run ${block}_synth \
    -flow {Vivado Implementation 2023} -strategy {Vivado Implementation Defaults}
}
current_run -synthesis      [get_runs synth_1]
current_run -implementation [get_runs impl_1]

# ---------------------------------------------------------------------------------------------
# Message suppressions (stored in the project)
# ---------------------------------------------------------------------------------------------
set_msg_config -id {Board 49-26}      -suppress
set_msg_config -id {filemgmt 56-199}  -suppress
set_msg_config -id {Synth 8-9661}     -string {{SALT}}     -suppress
set_msg_config -id {Synth 8-9661}     -string {{WIDTH}}    -suppress
set_msg_config -id {Netlist 29-101}   -string {{tea_hash}} -suppress

update_compile_order -fileset sources_1
foreach fs_name $simsets { update_compile_order -fileset [get_filesets $fs_name] }

# ---------------------------------------------------------------------------------------------
# Lint toolbar button (per-user Vivado setting, GUI only; skipped if it already exists)
# ---------------------------------------------------------------------------------------------
set lint_cmd "source {[file join $repo scripts/lint.tcl]}"
set is_gui [expr {[info exists ::rdi::mode] && $::rdi::mode eq "gui"}]
if {!$is_gui || [catch {
  catch { remove_gui_custom_commands lint_with_waivers }
  create_gui_custom_command -name lint_with_waivers -menu_name lint_with_waivers \
    -command $lint_cmd -show_on_toolbar -run_proc true
}]} {
  puts "INFO: \[CRAFT\] lint button not created (GUI only). In the GUI: Tools > Custom Commands >"
  puts "INFO: \[CRAFT\]   add 'lint_with_waivers' with command: $lint_cmd"
}

# ---------------------------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------------------------
puts "INFO: \[CRAFT\] ---------------------------------------------------------------"
puts "INFO: \[CRAFT\] Created $proj_dir/$proj_name.xpr"
puts "INFO: \[CRAFT\]   board part : [expr {$board_ok ? $board_part : {NOT SET (see warning above)}}]"
puts "INFO: \[CRAFT\]   synth top  : $synth_top"
puts "INFO: \[CRAFT\]   simsets    : $simsets (active: $active_simset)"
puts "INFO: \[CRAFT\]   OOC runs   : [join $ooc_blocks {, }] (<block>_synth / <block>_impl on 'ooc')"
puts "INFO: \[CRAFT\] ---------------------------------------------------------------"

if {[info exists ::rdi::mode] && $::rdi::mode eq "batch"} {
  close_project
}
