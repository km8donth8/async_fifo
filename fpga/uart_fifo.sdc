create_clock -name sys_clk -period 37.037 [get_ports {sys_clk}]
create_generated_clock -name clk_13p5 -source [get_ports {sys_clk}] -divide_by 2 [get_pins {Gowin_rPLL_inst/rpll_inst/CLKOUT}]

//keep setup timed (bounds delay and skew to ~1 period), for gray ptr crossings
//ignore hold, since late capture is absorbed by 2ff sync
set_false_path -hold -from [get_clocks {sys_clk}]  -to [get_clocks {clk_13p5}]
set_false_path -hold -from [get_clocks {clk_13p5}] -to [get_clocks {sys_clk}]