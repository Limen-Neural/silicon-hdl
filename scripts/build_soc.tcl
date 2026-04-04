# build_soc.tcl
# Vivado build script for the Spikenaut SoC targeting Basys 3
#
# Library ownership (compile order matters):
#   lib_bridge  <- spikenaut-bridge-sv/rtl
#   lib_core    <- spikenaut-core-sv/rtl        (NO copies in soc-sv/rtl)
#   lib_soc     <- spikenaut-soc-sv/rtl         (wrappers + spikenaut_soc_basys3_top only)
#
# Top module: spikenaut_soc_basys3_top
#
# Usage (Vivado Tcl console or batch mode):
#   vivado -mode batch -source scripts/build_soc.tcl

# ---------------------------------------------------------------------------
# 0. Project setup
# ---------------------------------------------------------------------------
set repo_root [file normalize [file join [file dirname [info script]] ..]]

set project_name  spikenaut_soc
set project_dir   [file join $repo_root vivado_projects $project_name]
set part          xc7a35tcpg236-1

create_project -force $project_name $project_dir -part $part

# ---------------------------------------------------------------------------
# 1. lib_bridge  –  spikenaut-bridge-sv/rtl
# ---------------------------------------------------------------------------
set bridge_rtl [file join $repo_root spikenaut-bridge-sv rtl]

read_verilog -sv [list \
    [file join $bridge_rtl UartRx.sv]      \
    [file join $bridge_rtl UartTx.sv]      \
    [file join $bridge_rtl SiliconBridge.sv] \
]

# ---------------------------------------------------------------------------
# 2. lib_core  –  spikenaut-core-sv/rtl
#    All four canonical modules live here and ONLY here.
#    spikenaut-soc-sv/rtl does NOT contain these files.
# ---------------------------------------------------------------------------
set core_rtl [file join $repo_root spikenaut-core-sv rtl]

read_verilog -sv [list \
    [file join $core_rtl LifNeuron.sv]       \
    [file join $core_rtl WeightRam.sv]       \
    [file join $core_rtl NeuronParamRam.sv]  \
    [file join $core_rtl StdpController.sv]  \
]

# ---------------------------------------------------------------------------
# 3. lib_soc  –  spikenaut-soc-sv/rtl
#    Only SoC wrappers and the renamed top module.
# ---------------------------------------------------------------------------
set soc_rtl [file join $repo_root spikenaut-soc-sv rtl]

read_verilog -sv [list \
    [file join $soc_rtl Basys3_Top.sv]   \
]

# ---------------------------------------------------------------------------
# 4. Constraints
# ---------------------------------------------------------------------------
read_xdc [file join $repo_root constraints basys3.xdc]

# ---------------------------------------------------------------------------
# 5. Synthesis
# ---------------------------------------------------------------------------
set_property top spikenaut_soc_basys3_top [current_fileset]
synth_design -top spikenaut_soc_basys3_top -part $part

# ---------------------------------------------------------------------------
# 6. Implementation
# ---------------------------------------------------------------------------
opt_design
place_design
route_design

# ---------------------------------------------------------------------------
# 7. Bitstream
# ---------------------------------------------------------------------------
set output_dir [file join $project_dir output]
file mkdir $output_dir
write_bitstream -force [file join $output_dir ${project_name}.bit]

puts "=== build_soc.tcl complete: bitstream written to $output_dir ==="
