# Makefile for RISC-V Page Table Example

# Find RISC-V toolchain
ifneq ($(shell which riscv64-elf-gcc 2>/dev/null),)
    TOOLPREFIX = riscv64-elf-
else ifneq ($(shell which riscv64-unknown-elf-gcc 2>/dev/null),)
    TOOLPREFIX = riscv64-unknown-elf-
else
    $(error RISC-V toolchain not found. Install with: brew install riscv64-elf-gcc)
endif

CC = $(TOOLPREFIX)gcc
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

# Compiler flags
# -mcmodel=medany: Allows code to be loaded at any address
# -march=rv64imac_zicsr: RV64 with integer, multiply, atomic, compressed, CSR
CFLAGS = -Wall -Wextra -O2 -ffreestanding -nostdlib
CFLAGS += -march=rv64imac_zicsr -mabi=lp64 -mcmodel=medany

# QEMU settings
QEMU = qemu-system-riscv64
QEMUOPTS = -machine virt -bios none -kernel kernel.elf -m 128M -nographic

OBJS = start.o main.o

.PHONY: all clean run debug dump

all: kernel.elf

# Assemble startup code
start.o: start.S
	$(CC) $(CFLAGS) -c $< -o $@

# Compile C code
main.o: main.c
	$(CC) $(CFLAGS) -c $< -o $@

# Link everything together
kernel.elf: $(OBJS) linker.ld
	$(LD) -T linker.ld -o $@ $(OBJS)
	@echo ""
	@echo "Built kernel.elf"
	@echo "Run with: make run"

# Run in QEMU
run: kernel.elf
	@echo "Starting QEMU..."
	@echo "Watch the page table setup and memory tests!"
	@echo "Press Ctrl-A X to exit QEMU"
	@echo ""
	$(QEMU) $(QEMUOPTS)

# Run with GDB server
debug: kernel.elf
	@echo "Starting QEMU with GDB server on port 1234..."
	@echo "Connect with: riscv64-elf-gdb -ex 'target remote :1234' kernel.elf"
	$(QEMU) $(QEMUOPTS) -S -gdb tcp::1234

# Disassemble the kernel
dump: kernel.elf
	$(OBJDUMP) -d $<

# Show memory map
map: kernel.elf
	$(OBJDUMP) -h $<

# Show all symbols
symbols: kernel.elf
	$(TOOLPREFIX)nm -n $<

clean:
	rm -f *.o kernel.elf
