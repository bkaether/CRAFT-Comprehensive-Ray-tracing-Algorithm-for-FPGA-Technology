source [file join [file dirname [info script]] lint_waivers.tcl]
synth_design -top [get_property top [current_fileset]] -part [get_property part [current_project]] -lint