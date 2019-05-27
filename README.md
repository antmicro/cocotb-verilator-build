# Quick start guide

1. Install dependencies:

    apt-get install virtualenv build-essential

2. Clone the repository:

    git clone https://github.com/antmicro/cocotb-verilator-build.git build

3. Change working directory to cloned repository:

    cd build

4. Download missing submodules:

    git submodule update --init

5. Build and install Verilator in local environment

    make env/bin/verilator

6. Install cocotb in local environment:

    make env/bin/cocotb-config


# Examples

To run Cototb included examples simple run cocotb/name_of_the_example/run.
To clean directory with examples execute cocotb/name_of_the_example/clean.

Running `adder` example:

    make cocotb/adder/run

Runing `D flip-flop` example:

    make cocotb/dff/run

Running `axi_lite_slave`:

    make cocotb/axi_lite_slave/run