/*
 * ============================================================================
 * linker.ld - Linker Script for Bare-Metal RISC-V
 * ============================================================================
 *
 * THIS IS NOT CODE! This is a configuration file for the GNU linker (ld).
 * It tells the linker WHERE to place code and data in memory.
 *
 * The CPU never sees this file - it's only used at build time.
 *
 * ============================================================================
 */

/* Target architecture - tells linker what machine we're building for */
OUTPUT_ARCH(riscv)

/* Entry point - which symbol to mark as the start of execution */
/* The ELF header will contain this address */
ENTRY(_start)

/*
 * ============================================================================
 * MEMORY REGIONS
 * ============================================================================
 *
 * QEMU "virt" machine memory map:
 *
 *   Address Range           Description
 *   ──────────────────────────────────────────────
 *   0x00000000-0x00000FFF   Debug ROM
 *   0x00001000-0x00011FFF   Boot ROM (BIOS would go here)
 *   0x02000000-0x0200FFFF   CLINT (Core Local Interruptor - timers)
 *   0x0C000000-0x0FFFFFFF   PLIC (Platform-Level Interrupt Controller)
 *   0x10000000-0x10000FFF   UART0 (serial port) ← We write here!
 *   0x10001000-0x10001FFF   VirtIO devices
 *   0x80000000-0x87FFFFFF   RAM (128 MB default) ← Our code goes here!
 *
 */
MEMORY
{
    /*
     * Define a memory region named "RAM"
     *   (rwx) = readable, writable, executable
     *   ORIGIN = starting address
     *   LENGTH = size of region
     */
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128M
}

/* Stack size: 16KB is plenty for our simple program */
_stack_size = 0x4000;

/*
 * ============================================================================
 * SECTIONS
 * ============================================================================
 *
 * Sections are chunks of the program with different purposes:
 *
 *   .text   - Executable code (your functions)
 *   .rodata - Read-only data (string literals like "Hello")
 *   .data   - Initialized global variables (int x = 5;)
 *   .bss    - Uninitialized global variables (int y;) - zeroed at startup
 *
 */
SECTIONS
{
    /*
     * .text section - executable code
     * This MUST be first, starting at 0x80000000, because that's
     * where QEMU jumps to start execution.
     */
    .text : {
        *(.text.init)       /* Entry point first (from start.S) */
        *(.text .text.*)    /* All other code */
    } > RAM

    /*
     * .rodata section - read-only data
     * String literals like "Hello, World!" go here.
     */
    .rodata : {
        *(.rodata .rodata.*)
    } > RAM

    /*
     * .data section - initialized data
     * Global variables with initial values: int x = 42;
     */
    .data : {
        *(.data .data.*)
    } > RAM

    /*
     * .bss section - uninitialized data
     * Global variables without initial values: int y;
     * C requires these to be zero, so start.S clears this section.
     *
     * We define _bss_start and _bss_end symbols so start.S knows
     * what memory range to zero out.
     */
    .bss : {
        _bss_start = .;     /* Symbol at current address */
        *(.bss .bss.*)      /* All BSS sections */
        *(COMMON)           /* Common symbols (old C feature) */
        _bss_end = .;       /* Symbol at end */
    } > RAM

    /*
     * Stack - grows downward from _stack_top toward _stack_bottom
     *
     * The "." is the "location counter" - current address.
     * We align it, then reserve _stack_size bytes.
     */
    . = ALIGN(16);          /* Align to 16 bytes (RISC-V ABI requirement) */
    _stack_bottom = .;      /* Symbol for debugging */
    . = . + _stack_size;    /* Reserve stack space */
    _stack_top = .;         /* sp points here at startup */
}

/*
 * ============================================================================
 * SYMBOL SUMMARY
 * ============================================================================
 *
 * These symbols are created by this linker script and can be referenced
 * in assembly (start.S) or C code:
 *
 *   _bss_start   - Start of BSS section (to be zeroed)
 *   _bss_end     - End of BSS section
 *   _stack_bottom - Bottom of stack (lower address, not used much)
 *   _stack_top   - Top of stack (sp starts here)
 *
 * In C, you can reference these as:
 *   extern char _bss_start[];
 *   extern char _stack_top[];
 *
 * ============================================================================
 */
