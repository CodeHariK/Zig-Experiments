# Makefile for bare-metal RISC-V Hello World
#
# Prerequisites:
#   - RISC-V toolchain (riscv64-unknown-elf-gcc or riscv64-elf-gcc)
#   - QEMU with RISC-V support (qemu-system-riscv64)
#
# On macOS with Homebrew:
#   brew install riscv64-elf-gcc qemu
#
# On Ubuntu/Debian:
#   apt install gcc-riscv64-unknown-elf qemu-system-misc

# Try to find the RISC-V toolchain
ifneq ($(shell which riscv64-elf-gcc 2>/dev/null),)
    TOOLPREFIX = riscv64-elf-
else ifneq ($(shell which riscv64-unknown-elf-gcc 2>/dev/null),)
    TOOLPREFIX = riscv64-unknown-elf-
else
    $(error RISC-V toolchain not found. Install riscv64-elf-gcc or riscv64-unknown-elf-gcc)
endif

CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)as
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

# Compiler flags
CFLAGS = -Wall -Wextra -O2 -ffreestanding -nostdlib
CFLAGS += -march=rv64imac -mabi=lp64
CFLAGS += -mcmodel=medany

# QEMU configuration
QEMU = qemu-system-riscv64
QEMUOPTS = -machine virt -bios none -kernel kernel.elf
QEMUOPTS += -m 128M -nographic

# Source files
SRCS = start.S main.c
OBJS = start.o main.o

.PHONY: all clean run debug dump

all: kernel.elf kernel.bin

# Compile assembly
start.o: start.S
	$(CC) $(CFLAGS) -c $< -o $@

# Compile C
main.o: main.c
	$(CC) $(CFLAGS) -c $< -o $@

# Link into ELF
kernel.elf: $(OBJS) linker.ld
	$(LD) -T linker.ld -o $@ $(OBJS)
	@echo "Built kernel.elf"

# Create raw binary (useful for some bootloaders)
kernel.bin: kernel.elf
	$(OBJCOPY) -O binary $< $@
	@echo "Built kernel.bin"

# Run in QEMU
run: kernel.elf
	@echo "Starting QEMU... (Press Ctrl-A then X to exit)"
	$(QEMU) $(QEMUOPTS)

# Run with GDB server for debugging
debug: kernel.elf
	@echo "Starting QEMU with GDB server on port 1234..."
	@echo "Connect with: $(TOOLPREFIX)gdb -ex 'target remote :1234' kernel.elf"
	$(QEMU) $(QEMUOPTS) -S -gdb tcp::1234

# Disassemble the kernel
dump: kernel.elf
	$(OBJDUMP) -d $<

# Show section sizes
size: kernel.elf
	$(TOOLPREFIX)size $<

clean:
	rm -f *.o kernel.elf kernel.bin
