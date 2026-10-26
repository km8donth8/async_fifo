SIM ?= icarus
TOPLEVEL_LANG ?= verilog

TOPLEVEL := async_fifo_axis
COCOTB_TEST_MODULES := test_async_fifo_axis

RTL_DIR := $(abspath ../rtl)
TEST_DIR := $(abspath ../tests)

VERILOG_SOURCES := \
	$(RTL_DIR)/sync_ff.v \
	$(RTL_DIR)/fifo_mem.v \
	$(RTL_DIR)/wptr_full.v \
	$(RTL_DIR)/rptr_empty.v \
	$(RTL_DIR)/async_fifo.v \
	$(RTL_DIR)/async_fifo_axis.v

PYTHONPATH := $(TEST_DIR):$(PYTHONPATH)
export PYTHONPATH

# Parse .v files as SystemVerilog.
COMPILE_ARGS += -g2012

RANDOM_SEED ?= 12345
RANDOM_PACKETS ?= 500

export RANDOM_SEED
export RANDOM_PACKETS

include $(shell cocotb-config --makefiles)/Makefile.sim