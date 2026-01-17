/*
 * linker.ld - Linker Script for Page Table Example
 *
 * Memory Layout:
 *   0x80000000  Kernel code and data
 *   0x80080000  Page tables (reserved)
 *   0x80090000  Stack
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    /* QEMU virt machine RAM starts at 0x80000000 */
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128M
}

/* Reserve space for page tables at 0x80080000 */
_page_table_start = 0x80080000;
_page_table_size = 0x10000;     /* 64 KB for page tables */

_stack_size = 0x4000;           /* 16 KB stack */
_trap_frame_size = 32 * 8;      /* 32 registers * 8 bytes */

SECTIONS
{
    /* Code section - starts at RAM origin */
    .text : {
        *(.text.init)           /* Entry point first */
        *(.text .text.*)        /* All other code */
    } > RAM

    /* Read-only data */
    .rodata : {
        *(.rodata .rodata.*)
    } > RAM

    /* Initialized data */
    .data : {
        *(.data .data.*)
    } > RAM

    /* Uninitialized data (cleared to zero by startup code) */
    .bss : {
        _bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(8);
        _bss_end = .;
    } > RAM

    /* Ensure we don't overflow into page table area */
    ASSERT(. < _page_table_start, "Code/data overlaps with page table region!")

    /* Page table region (reserved, defined in code) */
    . = _page_table_start + _page_table_size;
    _page_table_root = _page_table_start;

    /* Trap frame - for saving registers during traps */
    . = ALIGN(16);
    _trap_frame = .;
    . = . + _trap_frame_size;

    /* Stack */
    . = ALIGN(16);
    _stack_bottom = .;
    . = . + _stack_size;
    _stack_top = .;

    /* Provide symbols for debugging */
    _end = .;
}
