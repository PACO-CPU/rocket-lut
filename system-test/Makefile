

CROSS_COMPILE?=$(RISCV)/bin/riscv64-unknown-elf-
CLANG?=$(RISCV)/bin/clang

UART?=/dev/ttyUSB0

CFLAGS+= \
  -Iinclude \
  -I$(RISCV)/include \
  -I$(RISCV)/../rocket-soc/rocket_soc/fw/boot/src \
  -I$(RISCV)/../rocket-soc/rocket_soc/fw/common \
  -std=gnu99 -static -fno-common -fno-builtin-printf \
  -march=RV64IMA

LFLAGS+= \
  -L$(RISCV)/lib \
  -lrocket \
	-nostdlib -nostartfiles

TARGETS=main main.dump main.bin

all: $(TARGETS)

install: bootimage.hex
	cp bootimage.hex $(RISCV)/../rocket-soc/rocket_soc/fw_images/

run: main.bin
	riscv-uart-flash -i -w main.bin -p $(UART)

boot: bootimage.hex

bootimage.hex: bootimage
	elf2hex 16 512 bootimage > bootimage.hex

bootimage: main.o crt.o trap.o
	$(CROSS_COMPILE)gcc $^ -o $@ $(LFLAGS) -T boot.ld

main: main.o
	$(CROSS_COMPILE)gcc $^ -o $@ $(LFLAGS) -T main.ld

main.bin: main
	$(CROSS_COMPILE)objcopy -O binary main main.bin

main.dump: main
	$(CROSS_COMPILE)objdump -D main > main.dump

main.s: main.c test_data.c
	$(CROSS_COMPILE)gcc $(CFLAGS) -S $< -o $@ 

main.o: main.s
	../../../../riscv-tools-src/riscv-gnu-toolchain/build/build-binutils-newlib/gas/as-new main.s -o main.o
#	$(CROSS_COMPILE)gcc $(CFLAGS) -S $^ -o $@ 

crt.o: crt.S
	$(CROSS_COMPILE)gcc $(CFLAGS) -c -D__ASSEMBLY__=1 $^ -o $@

%.o:%.c
	$(CROSS_COMPILE)gcc $(CFLAGS) -c $^ -o $@ 

test_data.c:
	./create_test_asm_config.py

clean:
	rm -f $(TARGETS) *.o bootimage bootimage.hex main.s test_data.c
