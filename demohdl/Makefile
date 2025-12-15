# Verilator simulator Makefile

# Module name (Veryl prefixes with project name)
MODULE = demohdl_Top

# Directories
SRC_DIR = src
TARGET_DIR = target
SIM_DIR = sim
OBJ_DIR = obj_dir

# Source files
TESTBENCH = $(SIM_DIR)/sim_main.cpp

# Default target
all: build

# Build Veryl to SystemVerilog
build:
	./veryl build

# Run Veryl integrated tests
test: build
	./veryl test

# Run tests with waveform output
test-wave: build
	./veryl test --wave

# Run verilator to generate C++ simulation
sim: build
	verilator --cc $(TARGET_DIR)/*.sv --exe $(TESTBENCH) --trace --public-flat-rw -Mdir $(OBJ_DIR) --top-module $(MODULE)
	$(MAKE) -C $(OBJ_DIR) -f V$(MODULE).mk

# Run C++ simulation
run: sim
	@mkdir -p vcd
	./$(OBJ_DIR)/V$(MODULE)

# View waveform
wave:
	open vcd/*.vcd

# Clean build
clean:
	rm -rf $(OBJ_DIR) target vcd

.PHONY: all build test test-wave sim run wave clean
