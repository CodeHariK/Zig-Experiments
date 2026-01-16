# Bare-Metal RISC-V Hello World

A minimal "Hello, World!" program that runs directly on RISC-V hardware (via QEMU), with no operating system.

---

## What is Assembly vs Linker Script?

### `start.S` - Assembly Code (RISC-V instructions)

**Assembly is actual CPU instructions** that the processor executes. The `.S` file contains RISC-V assembly that gets assembled into machine code (binary).

```
Source (.S)  →  Assembler  →  Object file (.o)  →  Linker  →  Executable (ELF)
```

**Assembly tells the CPU WHAT to do:**
- Load values into registers
- Add/subtract numbers
- Jump to addresses
- Read/write memory

### `linker.ld` - Linker Script (NOT code!)

**The linker script is a configuration file** that tells the **linker** (not the CPU) WHERE to place code and data in memory.

```
Object files (.o)  +  Linker Script (.ld)  →  Linker  →  Final executable
```

**Linker script tells the linker WHERE things go:**
- Put code at address `0x80000000`
- Put data after code
- Reserve space for stack
- Define symbols like `_stack_top`

### Analogy

| File | Real-world analogy |
|------|-------------------|
| `start.S` | The actual recipe instructions ("mix flour, add eggs...") |
| `linker.ld` | The kitchen layout ("put stove here, fridge there...") |

The CPU executes assembly. The CPU **never sees** the linker script - it's only used at build time.

---

## Prerequisites

### macOS (Homebrew)
```bash
brew install riscv64-elf-gcc qemu
```

### Ubuntu/Debian
```bash
sudo apt install gcc-riscv64-unknown-elf qemu-system-misc
```

## Building and Running

```bash
make        # Build the kernel
make run    # Run in QEMU
```

To exit QEMU: Press `Ctrl-A` then `X`

## Project Structure

```
hello_world/
├── start.S      # Assembly entry point (sets up stack, calls main)
├── main.c       # C code (UART driver, prints "Hello, World!")
├── linker.ld    # Linker script (memory layout)
├── Makefile     # Build system
└── Readme.md    # This file
```

## How It Works

### 1. Boot Process

When QEMU starts with `-machine virt`:
1. CPU starts executing at address `0x80000000`
2. Our code (`start.S`) is loaded there via `-kernel kernel.elf`
3. No BIOS/bootloader - we're truly bare metal

### 2. Memory Map (QEMU virt machine)

| Address Range | Description |
|--------------|-------------|
| `0x10000000` | UART0 (serial port) |
| `0x80000000` | RAM start (our code goes here) |

### 3. start.S - The Entry Point (RISC-V Assembly)

This is **RISC-V assembly code**. Let's break down every line:

```asm
.section .text.init      # Assembler directive: put following code in section ".text.init"
.global _start           # Make "_start" visible to linker (entry point)

_start:                  # Label - this address is where execution begins
    la sp, _stack_top    # Load Address: sp = address of _stack_top symbol
```

#### Instruction-by-instruction breakdown:

| Instruction | Meaning | English |
|-------------|---------|---------|
| `la sp, _stack_top` | Load Address | Put the address of `_stack_top` into register `sp` |
| `la t0, _bss_start` | Load Address | Put BSS start address into temp register `t0` |
| `beq t0, t1, done` | Branch if Equal | If `t0 == t1`, jump to label `done` |
| `sd zero, 0(t0)` | Store Doubleword | Write 8 bytes of zeros to address in `t0` |
| `addi t0, t0, 8` | Add Immediate | `t0 = t0 + 8` |
| `j bss_clear` | Jump | Unconditional jump to label `bss_clear` |
| `call main` | Call function | Jump to `main`, save return address in `ra` |
| `wfi` | Wait For Interrupt | Halt CPU until interrupt (low power) |

#### Assembler Directives (not CPU instructions!):

| Directive | Meaning |
|-----------|---------|
| `.section .text.init` | Put following code in this section |
| `.global _start` | Export symbol so linker can see it |
| `label:` | Define a symbol at this address |

**Key concepts:**
- **Stack**: RISC-V uses register `sp` for the stack. We point it to the end of our reserved stack space.
- **BSS**: Uninitialized global variables. C expects these to be zero, so we clear them.
- **WFI**: "Wait For Interrupt" - low-power halt instruction.

### 4. main.c - UART Output

The UART (Universal Asynchronous Receiver/Transmitter) is how we communicate with the outside world:

```c
#define UART0_BASE 0x10000000UL

void uart_putc(char c) {
    // Wait until transmitter is ready
    while ((uart_read(UART_LSR) & UART_LSR_TX_EMPTY) == 0);
    // Write character
    uart_write(UART_THR, c);
}
```

**UART registers (16550 compatible):**
- `THR` (offset 0): Write bytes here to transmit
- `LSR` (offset 5): Status register - bit 5 = "transmitter empty"

### 5. linker.ld - Memory Layout (Linker Script)

**This is NOT assembly!** It's a configuration language for the GNU linker (`ld`).

```ld
OUTPUT_ARCH(riscv)           /* Target architecture */
ENTRY(_start)                /* Entry point symbol - where execution begins */

MEMORY {
    /* Define a memory region named "RAM" */
    /* rwx = read, write, execute permissions */
    /* ORIGIN = start address, LENGTH = size */
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128M
}

SECTIONS {
    /* .text section contains executable code */
    .text : {
        *(.text.init)    /* Include all .text.init sections first */
        *(.text .text.*) /* Then all other .text sections */
    } > RAM              /* Place in RAM region */

    /* .bss section - uninitialized data (zeroed at startup) */
    .bss : {
        _bss_start = .;  /* Define symbol at current address */
        *(.bss .bss.*)   /* Include all .bss sections */
        _bss_end = .;    /* Define symbol at end */
    } > RAM

    /* Stack - we define symbols the assembly code references */
    . = ALIGN(16);       /* Align to 16 bytes */
    _stack_bottom = .;   /* Symbol for stack bottom */
    . = . + 0x4000;      /* Reserve 16KB (. = current address) */
    _stack_top = .;      /* Symbol for stack top */
}
```

#### Linker Script Syntax:

| Syntax | Meaning |
|--------|---------|
| `ENTRY(_start)` | Tell linker which symbol is the entry point |
| `MEMORY { }` | Define memory regions with addresses |
| `SECTIONS { }` | Define how to arrange code/data sections |
| `. = address` | Set current location counter |
| `*(.text)` | Include all `.text` sections from all input files |
| `symbol = .` | Create a symbol at current address |
| `> RAM` | Place this section in the RAM memory region |
| `ALIGN(n)` | Align to n-byte boundary |

#### What are Sections?

When you compile C code, the compiler puts different things in different **sections**:

| Section | Contains | Example |
|---------|----------|---------|
| `.text` | Executable code | Your functions |
| `.rodata` | Read-only data | String literals `"hello"` |
| `.data` | Initialized globals | `int x = 5;` |
| `.bss` | Uninitialized globals | `int y;` (will be zeroed) |

The linker script arranges these sections in memory.

## Debugging

### Disassemble the kernel
```bash
make dump
```

### Debug with GDB
```bash
# Terminal 1: Start QEMU with GDB server
make debug

# Terminal 2: Connect GDB
riscv64-elf-gdb -ex 'target remote :1234' kernel.elf
(gdb) break main
(gdb) continue
(gdb) info registers
```

## RISC-V Basics

### Registers

RISC-V has **32 general-purpose registers** (x0-x31). Each has a name and convention:

| Register | ABI Name | Description | Saved by |
|----------|----------|-------------|----------|
| x0 | `zero` | Hardwired to 0 (writes ignored) | - |
| x1 | `ra` | Return address | Caller |
| x2 | `sp` | Stack pointer | Callee |
| x3 | `gp` | Global pointer | - |
| x4 | `tp` | Thread pointer | - |
| x5-x7 | `t0-t2` | Temporary registers | Caller |
| x8 | `s0/fp` | Saved register / Frame pointer | Callee |
| x9 | `s1` | Saved register | Callee |
| x10-x11 | `a0-a1` | Function args / Return values | Caller |
| x12-x17 | `a2-a7` | Function arguments | Caller |
| x18-x27 | `s2-s11` | Saved registers | Callee |
| x28-x31 | `t3-t6` | Temporary registers | Caller |

**Caller-saved**: Function can trash these, caller must save if needed.
**Callee-saved**: Function must restore before returning.

### Common Instructions

| Instruction | Format | Description |
|-------------|--------|-------------|
| `li rd, imm` | `li t0, 42` | Load immediate: `t0 = 42` |
| `la rd, sym` | `la t0, label` | Load address: `t0 = &label` |
| `mv rd, rs` | `mv t0, t1` | Move/copy: `t0 = t1` |
| `add rd, rs1, rs2` | `add t0, t1, t2` | Add: `t0 = t1 + t2` |
| `addi rd, rs, imm` | `addi t0, t1, 5` | Add immediate: `t0 = t1 + 5` |
| `lw rd, off(rs)` | `lw t0, 8(sp)` | Load word: `t0 = *(sp+8)` (32-bit) |
| `sw rs, off(rd)` | `sw t0, 8(sp)` | Store word: `*(sp+8) = t0` (32-bit) |
| `ld rd, off(rs)` | `ld t0, 0(sp)` | Load doubleword (64-bit) |
| `sd rs, off(rd)` | `sd t0, 0(sp)` | Store doubleword (64-bit) |
| `beq rs1, rs2, label` | `beq t0, t1, done` | Branch if equal |
| `bne rs1, rs2, label` | `bne t0, zero, loop` | Branch if not equal |
| `blt rs1, rs2, label` | `blt t0, t1, less` | Branch if less than |
| `j label` | `j loop` | Unconditional jump |
| `jal label` | `jal func` | Jump and link (call) |
| `jalr rd, rs, off` | `jalr ra, t0, 0` | Jump and link register |
| `ret` | `ret` | Return (alias for `jalr zero, ra, 0`) |
| `call label` | `call printf` | Function call (pseudo-instruction) |
| `nop` | `nop` | No operation |
| `wfi` | `wfi` | Wait for interrupt (halt) |

### Pseudo-instructions

Some "instructions" are actually **pseudo-instructions** that the assembler expands:

| Pseudo | Expands to | Meaning |
|--------|------------|---------|
| `li t0, 123` | `addi t0, zero, 123` | Load small immediate |
| `la t0, sym` | `auipc t0, ... ; addi t0, ...` | Load address |
| `mv t0, t1` | `addi t0, t1, 0` | Copy register |
| `ret` | `jalr zero, ra, 0` | Return |
| `call func` | `auipc ra, ... ; jalr ra, ...` | Call function |
| `j label` | `jal zero, label` | Jump (don't save return) |

---

## How It All Fits Together

```
┌──────────────────────────────────────────────────────────────────┐
│                        BUILD PROCESS                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│   start.S ──────┐                                                │
│   (assembly)    │                                                │
│                 ├──→ Assembler ──→ start.o ──┐                   │
│                 │       (as)       (object)  │                   │
│                 │                            │                   │
│   main.c ───────┤                            ├──→ Linker ──→ kernel.elf │
│   (C code)      │                            │      (ld)    (executable) │
│                 ├──→ Compiler ───→ main.o ───┤                   │
│                 │       (gcc)     (object)   │                   │
│                 │                            │                   │
│   linker.ld ────┴────────────────────────────┘                   │
│   (memory map)        (tells linker WHERE to put things)         │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                        RUNTIME (QEMU)                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│   Memory Address        Contents                                  │
│   ─────────────────────────────────────────                      │
│   0x10000000           UART registers (hardware I/O)             │
│        ...                                                        │
│   0x80000000           _start: (our code begins here!)           │
│   0x80000xxx           main(), uart_putc(), etc.                 │
│   0x80001xxx           "Hello, World!\n" (string data)           │
│   0x80002xxx           _bss_start (uninitialized globals)        │
│   0x80003xxx           _stack_bottom                              │
│   0x80007xxx           _stack_top (sp points here)               │
│                                                                   │
│   Execution flow:                                                 │
│   1. QEMU loads kernel.elf, jumps to 0x80000000                  │
│   2. _start runs: sets up sp, clears BSS                         │
│   3. _start calls main()                                          │
│   4. main() writes to UART at 0x10000000                         │
│   5. Characters appear on your terminal!                          │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Next Steps

After understanding this:
1. Add keyboard input (read from UART)
2. Implement `printf`-like formatting
3. Set up interrupts and timers
4. Explore memory management (page tables)
5. Study xv6-riscv source code!

## Resources

- [RISC-V Specification](https://riscv.org/specifications/)
- [QEMU RISC-V Virt Machine](https://www.qemu.org/docs/master/system/riscv/virt.html)
- [xv6-riscv](https://github.com/mit-pdos/xv6-riscv)
- [RISC-V Assembly Programmer's Manual](https://github.com/riscv-non-isa/riscv-asm-manual)
