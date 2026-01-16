/*
 * linker.ld - Linker Script for Interrupt Example
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128M
}

_stack_size = 0x4000;       /* 16 KB stack */
_trap_frame_size = 32 * 8;  /* 32 registers * 8 bytes each */

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > RAM

    .rodata : {
        *(.rodata .rodata.*)
    } > RAM

    .data : {
        *(.data .data.*)
    } > RAM

    .bss : {
        _bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(8);
        _bss_end = .;
    } > RAM

    /* Trap frame - space for saving registers during interrupt */
    . = ALIGN(16);
    _trap_frame = .;
    . = . + _trap_frame_size;

    /* Stack */
    . = ALIGN(16);
    _stack_bottom = .;
    . = . + _stack_size;
    _stack_top = .;
}
