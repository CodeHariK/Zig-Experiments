# ============================================================================
# start.S - RISC-V Bare Metal Entry Point
# ============================================================================
#
# This is RISC-V ASSEMBLY - actual CPU instructions!
# The assembler (as) converts this text to binary machine code.
#
# QEMU's "virt" machine loads our code at address 0x80000000
# and begins execution at the symbol we mark as ENTRY in linker.ld
#
# File extension: .S (capital S) means "assembly with C preprocessor"
#                 .s (lowercase) means "pure assembly"
# ============================================================================

# ----------------------------------------------------------------------------
# ASSEMBLER DIRECTIVES (instructions to assembler, not CPU)
# ----------------------------------------------------------------------------

.section .text.init     # Put this code in section ".text.init"
                        # Linker script places this FIRST in memory

.global _start          # Export "_start" symbol so linker can see it
                        # ENTRY(_start) in linker.ld references this

# ----------------------------------------------------------------------------
# _start - Entry point (first instruction executed!)
# ----------------------------------------------------------------------------
_start:
    # ---- Step 1: Set up the stack pointer ----
    # RISC-V has no built-in stack - we must set it up!
    # Register sp (x2) is the stack pointer by convention.
    # Stack grows DOWNWARD, so we point to the TOP (highest address).
    #
    # la = "Load Address" pseudo-instruction
    # _stack_top is a symbol defined in linker.ld
    
    la      sp, _stack_top

    # ---- Step 2: Clear the BSS section ----
    # BSS = "Block Started by Symbol" (historical name)
    # Contains uninitialized global variables (e.g., "int x;")
    # C standard requires these to be ZERO at program start.
    #
    # _bss_start and _bss_end are symbols from linker.ld
    
    la      t0, _bss_start      # t0 = start address of BSS
    la      t1, _bss_end        # t1 = end address of BSS

bss_clear:
    beq     t0, t1, bss_done    # if (t0 == t1) goto bss_done
    sd      zero, 0(t0)         # Store 8 bytes of zeros at address t0
                                # zero (x0) is always 0 in RISC-V
    addi    t0, t0, 8           # t0 = t0 + 8 (move to next 8 bytes)
    j       bss_clear           # Jump back to loop

bss_done:
    # ---- Step 3: Call main() ----
    # Now we can run C code! The C runtime is "set up":
    # - Stack pointer is valid
    # - BSS is zeroed
    #
    # call = pseudo-instruction that does:
    #   1. Save return address in ra (x1)
    #   2. Jump to main

    call    main

    # ---- Step 4: Halt if main() returns ----
    # main() should loop forever, but if it returns, we halt.
    # wfi = "Wait For Interrupt" - puts CPU in low-power state

halt:
    wfi                         # Wait for interrupt
    j       halt                # Loop forever (in case of spurious wakeup)

# ============================================================================
# End of start.S
# ============================================================================
