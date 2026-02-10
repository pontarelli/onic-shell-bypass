NO_COLOR=\e[0m
OK_COLOR=\e[32;01m
ERROR_COLOR=\e[31;01m
WARN_COLOR=\e[33;01m
OK_STRING=$(OK_COLOR)[OK]$(NO_COLOR)
COMMIT_HASH := $(shell git rev-parse --short HEAD)

.PHONY: au280-2 clean 

help:
	@echo -e '$(OK_COLOR)'
	@echo -e 'Usage: $(NO_COLOR)'
	@echo -e 'make help: display this message'
	@echo -e 'make au55n: build the project and the bitstream for the AU55N with 1 CMAC'
	@echo -e 'make au55n-2: build the project and the bitstream for the AU55N with 2 CMACs'
	@echo -e 'make au280: build the project and the bitstream for the AU280 with 1 CMAC'
	@echo -e 'make au280-2: build the project and the bitstream for the AU280 with 2 CMACs'
	@echo -e 'make clean: remove all files'


au55n:
	cd script; vivado -mode batch -source build.tcl -tclargs -build_timestamp $(COMMIT_HASH) -board au55n -num_phys_func 1 -num_cmac_port 1 -jobs 16 -tag cmac1
	@cp ./build/au55n_cmac1/open_nic_shell/open_nic_shell.runs/impl_1/open_nic_shell.bit onic_au55n_cmac1.bit
	@cp ./build/au55n_cmac1/open_nic_shell/open_nic_shell.runs/impl_1/open_nic_shell.mcs onic_au55n_cmac1.mcs
	@echo -e '$(OK_COLOR)[*] Created bitstream onic_au55n_cmac1.bit $(NO_COLOR)'

au55n-2:
	cd script; vivado -mode batch -source build.tcl -tclargs -build_timestamp $(COMMIT_HASH) -board au55n -num_phys_func 2 -num_cmac_port 2 -jobs 16 -tag cmac2
	@cp ./build/au55n_cmac2/open_nic_shell/open_nic_shell.runs/impl_1/open_nic_shell.bit onic_au55n_cmac2.bit
	@cp ./build/au55n_cmac2/open_nic_shell/open_nic_shell.runs/impl_1/open_nic_shell.mcs onic_au55n_cmac2.mcs
	@echo -e '$(OK_COLOR)[*] Created bitstream onic_au55n_cmac2.bit $(NO_COLOR)'

au280:
	cd script; vivado -mode batch -source build.tcl -tclargs -build_timestamp $(COMMIT_HASH) -board au280 -resynth -num_phys_func 1 -num_cmac_port 1 -jobs 16 -tag cmac1
	@cp ./build/au280_cmac1/open_nic_shell/open_nic_shell.runs/impl_1/open_nic_shell.bit onic_au280_cmac1.bit
	@cp ./build/au280_cmac1/open_nic_shell/open_nic_shell.runs/impl_1/open_nic_shell.mcs onic_au280_cmac1.mcs
	@echo -e '$(OK_COLOR)[*] Created bitstream onic_au280_cmac1.bit $(NO_COLOR)'

au280-2:
	cd script; vivado -mode batch -source build.tcl -tclargs -build_timestamp $(COMMIT_HASH) -board au280 -num_phys_func 2 -num_cmac_port 2 -jobs 16 -tag cmac2
	@cp ./build/au280_cmac2/open_nic_shell/open_nic_shell.runs/impl_1/open_nic_shell.bit onic_au280_cmac2.bit
	@cp ./build/au280_cmac2/open_nic_shell/open_nic_shell.runs/impl_1/open_nic_shell.mcs onic_au280_cmac2.mcs
	@echo -e '$(OK_COLOR)[*] Created bitstream onic_au280_cmac2.bit $(NO_COLOR)'

clean:
	@rm -rf build/*
	@echo -e '$(OK_COLOR)[*] Clean! $(NO_COLOR)'

