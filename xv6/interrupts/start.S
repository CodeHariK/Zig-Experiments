# ============================================================================
# start.S - RISC-V Entry Point with Interrupt Setup
# ============================================================================
#
# This sets up:
#   1. Stack pointer
#   2. Trap vector (where to jump on interrupts/exceptions)
#   3. Enables machine-mode interrupts
#   4. Calls main()
#
# ============================================================================

.section .text.init
.global _start

# ============================================================================
# RISC-V CSRs (Control and Status Registers) we use:
#
#   mstatus  - Machine Status (interrupt enable bits)
#   mtvec    - Machine Trap Vector (address of trap handler)
#   mie      - Machine Interrupt Enable (which interrupts to allow)
#   mcause   - Machine Cause (why did we trap?)
#   mepc     - Machine Exception PC (where to return after trap)
#   mscratch - Machine Scratch (we use for saving registers)
#
# ============================================================================

_start:
    # ---- Disable interrupts during setup ----
    csrw    mie, zero           # Clear all interrupt enable bits

    # ---- Set up stack ----
    la      sp, _stack_top

    # ---- Clear BSS ----
    la      t0, _bss_start
    la      t1, _bss_end
1:  beq     t0, t1, 2f
    sd      zero, 0(t0)
    addi    t0, t0, 8
    j       1b
2:

    # ---- Set up trap handler ----
    # mtvec holds the address of our trap handler
    # Mode bits [1:0]: 00 = Direct (all traps go to BASE)
    #                  01 = Vectored (interrupts go to BASE + 4*cause)
    # We use Direct mode for simplicity
    la      t0, trap_entry
    csrw    mtvec, t0

    # ---- Set up scratch register ----
    # mscratch will hold pointer to our trap frame (for saving registers)
    la      t0, _trap_frame
    csrw    mscratch, t0

    # ---- Call main to initialize and start timer ----
    call    main

    # ---- Enable interrupts and wait ----
    # If main returns, we just spin with interrupts enabled
spin:
    wfi
    j       spin


# ============================================================================
# Trap Entry Point
# ============================================================================
# When any interrupt or exception occurs, CPU jumps here.
# We need to:
#   1. Save all registers (so we can restore them later)
#   2. Call C handler
#   3. Restore registers
#   4. Return from trap (mret)
#
# Register convention:
#   - mscratch points to trap_frame (space for saved registers)
#   - We swap sp with mscratch to get trap_frame pointer
# ============================================================================

.global trap_entry
.align 4                        # Trap vector must be 4-byte aligned
trap_entry:
    # Swap sp and mscratch
    # After this: sp = trap_frame address, mscratch = old sp
    csrrw   sp, mscratch, sp

    # Save all general-purpose registers to trap frame
    sd      x1,   0*8(sp)       # ra
    sd      x3,   1*8(sp)       # gp
    sd      x4,   2*8(sp)       # tp
    sd      x5,   3*8(sp)       # t0
    sd      x6,   4*8(sp)       # t1
    sd      x7,   5*8(sp)       # t2
    sd      x8,   6*8(sp)       # s0/fp
    sd      x9,   7*8(sp)       # s1
    sd      x10,  8*8(sp)       # a0
    sd      x11,  9*8(sp)       # a1
    sd      x12, 10*8(sp)       # a2
    sd      x13, 11*8(sp)       # a3
    sd      x14, 12*8(sp)       # a4
    sd      x15, 13*8(sp)       # a5
    sd      x16, 14*8(sp)       # a6
    sd      x17, 15*8(sp)       # a7
    sd      x18, 16*8(sp)       # s2
    sd      x19, 17*8(sp)       # s3
    sd      x20, 18*8(sp)       # s4
    sd      x21, 19*8(sp)       # s5
    sd      x22, 20*8(sp)       # s6
    sd      x23, 21*8(sp)       # s7
    sd      x24, 22*8(sp)       # s8
    sd      x25, 23*8(sp)       # s9
    sd      x26, 24*8(sp)       # s10
    sd      x27, 25*8(sp)       # s11
    sd      x28, 26*8(sp)       # t3
    sd      x29, 27*8(sp)       # t4
    sd      x30, 28*8(sp)       # t5
    sd      x31, 29*8(sp)       # t6

    # Save original sp (currently in mscratch)
    csrr    t0, mscratch
    sd      t0, 30*8(sp)        # original sp

    # Set up kernel stack for C code
    la      sp, _stack_top

    # Call C trap handler
    call    trap_handler

    # Restore from trap frame
    la      sp, _trap_frame

    # Restore original sp to mscratch (for next trap)
    ld      t0, 30*8(sp)
    csrw    mscratch, t0

    # Restore all registers
    ld      x1,   0*8(sp)
    ld      x3,   1*8(sp)
    ld      x4,   2*8(sp)
    ld      x5,   3*8(sp)
    ld      x6,   4*8(sp)
    ld      x7,   5*8(sp)
    ld      x8,   6*8(sp)
    ld      x9,   7*8(sp)
    ld      x10,  8*8(sp)
    ld      x11,  9*8(sp)
    ld      x12, 10*8(sp)
    ld      x13, 11*8(sp)
    ld      x14, 12*8(sp)
    ld      x15, 13*8(sp)
    ld      x16, 14*8(sp)
    ld      x17, 15*8(sp)
    ld      x18, 16*8(sp)
    ld      x19, 17*8(sp)
    ld      x20, 18*8(sp)
    ld      x21, 19*8(sp)
    ld      x22, 20*8(sp)
    ld      x23, 21*8(sp)
    ld      x24, 22*8(sp)
    ld      x25, 23*8(sp)
    ld      x26, 24*8(sp)
    ld      x27, 25*8(sp)
    ld      x28, 26*8(sp)
    ld      x29, 27*8(sp)
    ld      x30, 28*8(sp)
    ld      x31, 29*8(sp)

    # Restore sp from mscratch
    csrrw   sp, mscratch, sp

    # Return from trap
    mret
