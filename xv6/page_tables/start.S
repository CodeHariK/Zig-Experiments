# ============================================================================
# start.S - RISC-V Entry Point with Page Table Setup
# ============================================================================
#
# This sets up:
#   1. Stack pointer (in Machine mode)
#   2. Page tables with identity mapping
#   3. Switches to Supervisor mode with paging enabled
#   4. Calls main()
#
# Key insight: We build page tables in M-mode (using physical addresses),
# then switch to S-mode where paging takes effect via satp.
#
# ============================================================================

.section .text.init
.global _start
.global trap_entry

# ============================================================================
# CSRs we use:
#
#   M-mode CSRs:
#     mstatus  - Machine Status (MPP field for privilege level on mret)
#     medeleg  - Machine Exception Delegation (delegate traps to S-mode)
#     mideleg  - Machine Interrupt Delegation
#     mepc     - Where to jump on mret
#     mie      - Machine Interrupt Enable
#
#   S-mode CSRs:
#     satp     - Supervisor Address Translation and Protection
#     sstatus  - Supervisor Status
#     stvec    - Supervisor Trap Vector
#     sepc     - Supervisor Exception PC
#     scause   - Supervisor Cause
#     stval    - Supervisor Trap Value (faulting address)
#
# ============================================================================

# MSTATUS bits
.equ MSTATUS_MPP_MASK, (3 << 11)
.equ MSTATUS_MPP_S,    (1 << 11)    # Previous mode = Supervisor
.equ MSTATUS_MPP_M,    (3 << 11)    # Previous mode = Machine

# SSTATUS bits
.equ SSTATUS_SIE,      (1 << 1)     # Supervisor Interrupt Enable

# Page table constants
.equ SATP_SV39,        (8 << 60)    # Sv39 mode in satp

_start:
    # ---- Disable all interrupts ----
    csrw    mie, zero
    csrw    mip, zero

    # ---- Set up stack (physical address, we're in M-mode) ----
    la      sp, _stack_top

    # ---- Clear BSS ----
    la      t0, _bss_start
    la      t1, _bss_end
1:  beq     t0, t1, 2f
    sd      zero, 0(t0)
    addi    t0, t0, 8
    j       1b
2:

    # ---- Delegate all traps to Supervisor mode ----
    # This means page faults etc. go to stvec, not mtvec
    li      t0, 0xffff
    csrw    medeleg, t0        # Delegate all exceptions
    csrw    mideleg, t0        # Delegate all interrupts

    # ---- Set up Supervisor trap handler ----
    la      t0, trap_entry
    csrw    stvec, t0

    # ---- Call C function to set up page tables ----
    # This builds identity-mapped page tables in memory
    call    setup_page_tables

    # ---- Get return value (root page table address) and set satp ----
    # setup_page_tables returns root table physical address in a0
    # satp format: | MODE (4) | ASID (16) | PPN (44) |
    srli    t0, a0, 12         # PPN = address >> 12
    li      t1, SATP_SV39      # Mode = Sv39
    or      t0, t0, t1         # Combine mode and PPN
    # Don't write to satp yet - we're still in M-mode!
    # We'll write it after switching to S-mode context

    # ---- Prepare to switch to Supervisor mode ----
    # Set mstatus.MPP = 01 (Supervisor mode)
    # When we execute mret, CPU will:
    #   1. Switch to privilege level in MPP
    #   2. Jump to address in mepc
    #   3. Set mstatus.MIE = mstatus.MPIE
    
    csrr    t1, mstatus
    li      t2, MSTATUS_MPP_MASK
    not     t2, t2
    and     t1, t1, t2         # Clear MPP bits
    li      t2, MSTATUS_MPP_S  # MPP = 01 (S-mode)
    or      t1, t1, t2
    csrw    mstatus, t1

    # ---- Set return address for mret ----
    la      t1, supervisor_entry
    csrw    mepc, t1

    # ---- Save satp value in mscratch for later ----
    csrw    mscratch, t0

    # ---- Switch to Supervisor mode! ----
    mret


# ============================================================================
# Supervisor Mode Entry Point
# ============================================================================
# We arrive here after mret, now running in S-mode.
# Paging is not yet enabled - satp still has its reset value (0).
#
# CRITICAL: We're using identity mapping, so after enabling paging,
# our code/stack addresses don't change!
# ============================================================================

supervisor_entry:
    # ---- Enable paging by writing to satp ----
    # Get the satp value we prepared earlier
    csrr    t0, mscratch       # Retrieve prepared satp value
    csrw    satp, t0           # PAGING IS NOW ENABLED!

    # ---- Flush the TLB ----
    # CRITICAL: After changing satp, TLB may have stale entries
    sfence.vma

    # ---- Set up trap frame for interrupt handling ----
    la      t0, _trap_frame
    csrw    sscratch, t0

    # ---- Call main ----
    call    main

    # ---- Spin if main returns ----
spin:
    wfi
    j       spin


# ============================================================================
# Trap Entry Point (S-mode)
# ============================================================================
# When a trap occurs in S-mode (page fault, interrupt, etc.),
# CPU jumps here via stvec.
#
# We save all registers, call C handler, restore, and return.
# ============================================================================

.align 4
trap_entry:
    # Swap sp with sscratch (sscratch points to trap frame)
    csrrw   sp, sscratch, sp

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

    # Save original sp (currently in sscratch)
    csrr    t0, sscratch
    sd      t0, 30*8(sp)        # original sp

    # Use kernel stack for C code
    la      sp, _stack_top

    # Call C trap handler
    call    trap_handler

    # Restore from trap frame
    la      sp, _trap_frame

    # Restore original sp to sscratch
    ld      t0, 30*8(sp)
    csrw    sscratch, t0

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

    # Restore sp from sscratch
    csrrw   sp, sscratch, sp

    # Return from trap
    sret
