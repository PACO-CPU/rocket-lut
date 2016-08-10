
RISCV?=../../riscv-tools

all:

install: all
	cp -r htlib $(RISCV)/py/
	cp tools/* $(RISCV)/bin/


