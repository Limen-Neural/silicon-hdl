# SPDX-License-Identifier: MIT OR Apache-2.0
# sim_core.tcl
# Vivado simulation script for spikenaut-core-sv unit testbenches
#
# Library ownership:
#   lib_bridge  <- spikenaut-bridge-sv/rtl
#   lib_core    <- spikenaut-core-sv/rtl
#   lib_tb_core <- spikenaut-core-sv/tb
#
# Usage (Vivado Tcl console or batch mode):
#   vivado -mode batch -source scripts/sim_core.tcl

# ---------------------------------------------------------------------------
# 0. Project setup
# ---------------------------------------------------------------------------
set repo_root [file normalize [file join [file dirname [info script]] ..]]

set project_name  spikenaut_sim_core
set project_dir   [file join $repo_root vivado_projects $project_name]
set part          xc7a35tcpg236-1

# Vivado 2026.1 rejects legacy -ip/-rtl_kernel boolean flags on create_project.
create_project -force $project_name $project_dir -part $part

set_property simulator_language Mixed [current_project]

# ---------------------------------------------------------------------------
# 1. lib_bridge  –  spikenaut-bridge-sv/rtl  (needed by some core TBs)
# ---------------------------------------------------------------------------
set bridge_rtl [file join $repo_root spikenaut-bridge-sv rtl]

read_verilog -sv [list \
    [file join $bridge_rtl UartRx.sv]        \
    [file join $bridge_rtl UartTx.sv]        \
    [file join $bridge_rtl SiliconBridge.sv] \
]

# ---------------------------------------------------------------------------
# 2. lib_core  –  spikenaut-core-sv/rtl (canonical, single copy)
# ---------------------------------------------------------------------------
set core_rtl [file join $repo_root spikenaut-core-sv rtl]

read_verilog -sv [list \
    [file join $core_rtl LifNeuron.sv]      \
    [file join $core_rtl WeightRam.sv]      \
    [file join $core_rtl NeuronParamRam.sv] \
    [file join $core_rtl StdpController.sv] \
]

# ---------------------------------------------------------------------------
# 3. lib_tb_core  –  spikenaut-core-sv/tb (testbenches)
# ---------------------------------------------------------------------------
set core_tb [file join $repo_root spikenaut-core-sv tb]

# Add all testbench files in tb/ if any exist
if {[llength [glob -nocomplain [file join $core_tb *.sv]]] > 0} {
    read_verilog -sv [glob [file join $core_tb *.sv]]
}

# ---------------------------------------------------------------------------
# 4. Run each unit testbench in turn
# ---------------------------------------------------------------------------
# (gh-14 5u3.8 addressed by making it run multiple; origin/main has the list
# from #11 + testbenches added.)
set core_tb_tops {tb_LifNeuron tb_WeightRam tb_WeightRam_init tb_NeuronParamRam tb_StdpController}

foreach tb_top $core_tb_tops {
    set_property top $tb_top [get_filesets sim_1]
    set_property top_lib xil_defaultlib [get_filesets sim_1]

    # Force re-elaboration when switching top modules to avoid stale
    # compilation artifacts / dirty directory issues in the sim fileset.
    # catch() guards the first iteration where the run may not exist yet.
    catch {reset_run sim_1}
    launch_simulation
    run 10us
    close_sim
}

puts "=== sim_core.tcl complete ==="
