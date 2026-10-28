create_clock -name sys_clk -period 37.037 [get_ports {sys_clk}]
create_generated_clock -name clk_13p5 -source [get_ports {sys_clk}] -divide_by 2 [get_pins {Gowin_rPLL_inst/rpll_inst/CLKOUT}]
set_clock_groups -asynchronous -group [get_clocks {sys_clk}] -group [get_clocks {clk_13p5}]