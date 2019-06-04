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

# ---------------------------------- TESTS ---------------------------------
SYSTEMC_URL = https://www.accellera.org/images/downloads/standards/systemc/systemc-2.3.3.tar.gz
VCDDIFF_URL = git@github.com:veripool/vcddiff.git

tests/.dir:
	mkdir `dirname $@` && touch $@


tests/systemc.tar.gz: tests/.dir
	wget -c $(SYSTEMC_URL) -O $@ && touch $@

tests/systemc/.unpack: tests/systemc.tar.gz
	mkdir tests/systemc && tar xf $< --strip-components=1 -C tests/systemc && touch $@

tests/systemc/.conf: tests/systemc/.unpack
	(cd tests/systemc && ./configure --prefix=$(PWD)/tests/systemc/image) && touch $@

tests/systemc/.build: tests/systemc/.conf
	(cd tests/systemc && make -j`nproc`) && touch $@

tests/systemc/.install: tests/systemc/.build
	(cd tests/systemc && make install) && touch $@


tests/vcddiff/.clone: tests/.dir
	git clone $(VCDDIFF_URL) tests/vcddiff && touch $@

tests/vcddiff/vcddiff: tests/vcddiff/.clone
	(cd tests/vcddiff && make -j`nproc`)


tests/.verilator_clone: tests/.dir
	git clone verilator tests/verilator && touch $@

tests/verilator/configure: tests/.verilator_clone
	(cd tests/verilator && autoconf)

tests/.verilator_conf: tests/verilator/configure
	(cd tests/verilator && ./configure --enable-longtests) && touch $@

tests/.verilator_build: tests/.verilator_conf
	(cd tests/verilator && make -j`nproc`) && touch $@


tests/verilator: tests/.verilator_build tests/vcddiff/vcddiff tests/systemc/.install
	(cd tests/verilator && \
		PATH=/home/lukas/cocotb/vcddiff:$$PATH \
		LD_LIBRARY_PATH=$(PWD)/tests/systemc/image/lib-linux64 \
		SYSTEMC_INCLUDE=$(PWD)/tests/systemc/image/include \
		SYSTEMC_LIBDIR=$(PWD)/tests/systemc/image/lib-linux64 \
			make test 2>&1 | tee $(PWD)/tests/log-`git rev-parse --verify HEAD`.txt)


tests/clean:
	rm -rf tests
