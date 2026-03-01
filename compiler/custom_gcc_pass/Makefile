PLUGIN=shadowstack_plugin.so
SRC=shadow_stack_plugin.cc

CROSS_GCCPLUGINS_DIR := $(shell riscv64-unknown-elf-gcc -print-file-name=plugin)
HOST_CXX = g++
CXXFLAGS = -shared -fPIC -O2 -std=gnu++17 \
           -I$(CROSS_GCCPLUGINS_DIR)/include \
           -fno-rtti -fno-exceptions -fno-threadsafe-statics

all:
	$(HOST_CXX) $(CXXFLAGS) $(SRC) -o $(PLUGIN)

clean:
	rm -f $(PLUGIN)
