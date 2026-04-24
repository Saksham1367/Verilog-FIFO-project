# Example CDC constraints for integrating the asynchronous FIFO into a Xilinx flow.
# Replace fifo_inst with the hierarchical instance name used in your design.

# Treat the read and write clocks as asynchronous to one another.
set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_pins fifo_inst/wr_clk]] \
    -group [get_clocks -of_objects [get_pins fifo_inst/rd_clk]]

# Optional: keep synchronizer placement tight if your implementation flow supports it.
# The exact cell names depend on synthesis output and hierarchy preservation.
# set_property ASYNC_REG TRUE [get_cells -hierarchical *rd_gray_sync1_reg*]
# set_property ASYNC_REG TRUE [get_cells -hierarchical *rd_gray_sync2_reg*]
# set_property ASYNC_REG TRUE [get_cells -hierarchical *wr_gray_sync1_reg*]
# set_property ASYNC_REG TRUE [get_cells -hierarchical *wr_gray_sync2_reg*]
