# basys3.xdc
# Physical constraints for the Digilent Basys 3 (Artix-7 XC7A35T-1CPG236C)
# Used by: spikenaut_soc_basys3_top, synapse_demo_basys3_top

## Clock – W5 (100 MHz)
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

## Reset – U18 (BTNU, active-high; invert to produce active-low rst_n)
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports rst_n]

## UART
set_property -dict {PACKAGE_PIN B18 IOSTANDARD LVCMOS33} [get_ports uart_rx]
set_property -dict {PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports uart_tx]

## LEDs LD0–LD15 
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {led[7]}]
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {led[8]}]
set_property -dict {PACKAGE_PIN V3  IOSTANDARD LVCMOS33} [get_ports {led[9]}]
set_property -dict {PACKAGE_PIN W3  IOSTANDARD LVCMOS33} [get_ports {led[10]}]
set_property -dict {PACKAGE_PIN U3  IOSTANDARD LVCMOS33} [get_ports {led[11]}]
set_property -dict {PACKAGE_PIN P3  IOSTANDARD LVCMOS33} [get_ports {led[12]}]
set_property -dict {PACKAGE_PIN N3  IOSTANDARD LVCMOS33} [get_ports {led[13]}]
set_property -dict {PACKAGE_PIN P1  IOSTANDARD LVCMOS33} [get_ports {led[14]}]
set_property -dict {PACKAGE_PIN L1  IOSTANDARD LVCMOS33} [get_ports {led[15]}]

# Neuron parameter RAMs (seperate threshold and leak)
# TODO: Add constraints for neuron parameter RAMs
logic [PARAM_WIDTH-1:0] threshold_val;
logic [PARAM_WIDTH-1:0] leak_val;

NeuronParam #(
   .ADDR_WIDTH (NEURON_ADDR_WIDTH),
   .PARAM_WIDTH (PARAM_WIDTH)
) u_threshold_ram (
    .clk  (clk),
    .we   (1'b0),
    .addr ('0),
    .din  ('0),
    .dout (threshold_val)
  );

  // Weight RAMs
  // TODO: Add constraints for weight RAMs
  logic [DATA_WIDTH-1:0] weight_dout;
  WeightRam #(
    .ADDR_WIDTH (WEIGHT_ADDR_W),
    .DATA_WIDTH (DATA_WIDTH)
  ) u_weight_ram (
    .clk  (clk),
    .we   (1'b0),
    .addr ('0),
    .din  ('0),
    .dout (weight_dout)
  );

// LIF neuron
// TODO: Add constraints for LIF neuron
logic spike_out;

LifNeuron #(
    .NEURON_ADDR_WIDTH (NEURON_ADDR_WIDTH),
    .PARAM_WIDTH (PARAM_WIDTH)
) u_lif_neuron (
    .clk (clk),
    .rst_n (rst_n),
    .spike_in (1'b0),
    .threshold_val (threshold_val),
    .leak_val (leak_val),
    .spike_out (spike_out)
);