SHELL = bash
QUIET ?= @
SIM ?= verilator

VERBOSE ?= 0

ifeq ($(VERBOSE),1)
	VL_C_FLAGS = -DVL_DEBUG
	VL_CPP_FLAGS = -DVL_DEBUG
	VL_CXX_FLAGS = -DVL_DEBUG

	COCOTB_APPEND = \
		COCOTB_SCHEDULER_DEBUG=1 \
		COCOTB_LOG_LEVEL=DEBUG
endif

IN_ENV = . env/bin/activate ;

all:
	@true

verilator/configure: verilator/configure.ac
	cd verilator && autoconf

verilator/.conf: verilator/configure
	(cd verilator && \
		CFLAGS="$(VL_C_FLAGS)" \
		CPPFLAGS="$(VL_CPP_FLAGS)" \
		CXXFLAGS="$(VL_CXX_FLAGS)" \
		./configure --prefix=$(PWD)/env) && touch $@

verilator/.build: verilator/.conf
	(cd verilator && make -j`nproc`) && touch $@

env/bin/verilator: verilator/.build
	(cd verilator && make install)

env/bin/activate:
	virtualenv --python=python3 env

env/bin/cocotb-config: env/bin/activate
	$(IN_ENV) pip install -e ./cocotb

env/enter: env/bin/activate env/bin/cocotb-config env/bin/verilator
	$(QUIET)$(IN_ENV) env \
		CMD=$(PWD)/env/bin/verilator \
		SIM=verilator \
		PYTHONDONTWRITEBYTECODE=1 \
		bash --rcfile <( \
			cat $$HOME/.bashrc ; \
			echo 'PS1="(cocotb) $$PS1"' \
		) || true

define cocotb_target_raw
cocotb/$(1)/$(2):
	$$(QUIET)$$(IN_ENV) env \
		CMD=$$(PWD)/env/bin/verilator \
		SIM=$(SIM) \
		PYTHONDONTWRITEBYTECODE=1 \
		$(COCOTB_APPEND) \
		bash -c "cd cocotb/examples/$(1)/tests ; make $(3)"
endef

define cocotb_target
$(eval $(call cocotb_target_raw,$(1),run,))
$(eval $(call cocotb_target_raw,$(1),clean,clean))
endef

COCOTB_EXAMPLES = $(shell for p in cocotb/examples/* ; do [ -d $$p ] && echo $$p | cut -d\/ -f3 ; done)

$(foreach t,$(COCOTB_EXAMPLES),$(eval $(call cocotb_target,$(t))))
