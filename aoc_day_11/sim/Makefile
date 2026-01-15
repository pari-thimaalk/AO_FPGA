SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

PKG_SRCS := $(PWD)/../pkg/types.sv
HDL_SRCS := $(shell find $(PWD)/../hdl -name '*.sv')
HVL_SRCS := $(shell find $(PWD)/../hvl -name '*.sv')
SRCS := $(PKG_SRCS) $(HDL_SRCS) $(HVL_SRCS)

export VCS_ARCH_OVERRIDE=linux
VCS_FLAGS= -full64 -lca -sverilog +lint=all,noNS -timescale=1ns/1ns -debug_acc+all -kdb -debug_access -suppress=LCA_FEATURES_ENABLED -j4 +notimingcheck

vcs/%_tb: $(SRCS)
	mkdir -p vcs
	cd vcs && vcs $(SRCS) $(VCS_FLAGS) -msg_config=../vcs_warn.config -l $*_tb_compile.log -top $*_tb -o $*_tb

.PHONY: run_%_tb
run_%_tb: vcs/%_tb
	rm -f vcs/dump.fsdb
	cd vcs && ./$*_tb -l $*_tb_sim.log

.PHONY: verdi
verdi:
	mkdir -p verdi
	cd verdi && $(VERDI_HOME)/bin/verdi -ssf $(PWD)/vcs/dump.fsdb

.PHONY: clean
clean:
	rm -rf bin sim verdi