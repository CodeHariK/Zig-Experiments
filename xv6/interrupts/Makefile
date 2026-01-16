# Makefile for RISC-V Timer Interrupt Example

ifneq ($(shell which riscv64-elf-gcc 2>/dev/null),)
    TOOLPREFIX = riscv64-elf-
else ifneq ($(shell which riscv64-unknown-elf-gcc 2>/dev/null),)
    TOOLPREFIX = riscv64-unknown-elf-
else
    $(error RISC-V toolchain not found)
endif

CC = $(TOOLPREFIX)gcc
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

CFLAGS = -Wall -Wextra -O2 -ffreestanding -nostdlib
CFLAGS += -march=rv64imac_zicsr -mabi=lp64 -mcmodel=medany

QEMU = qemu-system-riscv64
QEMUOPTS = -machine virt -bios none -kernel kernel.elf -m 128M -nographic

OBJS = start.o main.o

.PHONY: all clean run debug dump

all: kernel.elf

start.o: start.S
	$(CC) $(CFLAGS) -c $< -o $@

main.o: main.c
	$(CC) $(CFLAGS) -c $< -o $@

kernel.elf: $(OBJS) linker.ld
	$(LD) -T linker.ld -o $@ $(OBJS)
	@echo "Built kernel.elf"

run: kernel.elf
	@echo "Starting QEMU... (Ctrl-A X to exit)"
	@echo "Watch for timer interrupts every second!"
	$(QEMU) $(QEMUOPTS)

debug: kernel.elf
	$(QEMU) $(QEMUOPTS) -S -gdb tcp::1234

dump: kernel.elf
	$(OBJDUMP) -d $<

clean:
	rm -f *.o kernel.elf
