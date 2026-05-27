# ==============================================================================
# 1. Simulation Settings (Cocotb & Icarus Verilog)
# ==============================================================================
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Ensure make knows where to find the Verilog source files
VERILOG_SOURCES += $(PWD)/hdl/pwm_generator.v
VERILOG_SOURCES += $(PWD)/hdl/spi_slave.v
VERILOG_SOURCES += $(PWD)/hdl/top_motor_controller.v

# The Python test file inside the tests/ directory (without the .py extension)
MODULE = tests.test_spi_pwm

# The top-level Verilog module name
TOPLEVEL = top_motor_controller

# Cocotb boilerplate
include $(shell cocotb-config --makefiles)/Makefile.sim


# ==============================================================================
# 2. Synthesis Settings (Quartus CLI)
# ==============================================================================
PROJECT = top_motor_controller
DEVICE = EP4CE6E22C8
synth:
	@echo "Starting Quartus Synthesis..."
	# Run the compilation steps
	quartus_map --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(PROJECT)
	quartus_fit --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(PROJECT)
	quartus_asm --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(PROJECT)
    
	@echo "Sweeping Quartus build artifacts into build/ directory..."
	mkdir -p build/output_files
    
    # Move ONLY the final output files and reports into build/
	mv output_files/* build/output_files/ 2>/dev/null || true
	rm -rf output_files/
	mv *.rpt *.summary *.smsg *.qws *.jdi *.pin build/output_files/ 2>/dev/null || true
    
	@echo "Synthesis Complete! Bitstream generated at: build/output_files/$(PROJECT).sof"
	
# ==============================================================================
# 3. Cleanup
# ==============================================================================
clean_all: clean
	rm -rf build/
	rm -rf db/ incremental_db/ output_files/
	rm -f *.rpt *.summary *.smsg *.qws *.jdi *.pin