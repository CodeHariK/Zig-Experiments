# RISC-V Timer Interrupts

This example demonstrates **hardware interrupts** and **timers** on RISC-V.

## Quick Start

```bash
make        # Build
make run    # Run (watch for timer interrupts every second!)
```

Press `Ctrl-A` then `X` to exit QEMU.

---

## What This Demonstrates

1. **CLINT** (Core Local Interruptor) - The timer hardware
2. **Trap handling** - What happens when an interrupt fires
3. **CSRs** - Control and Status Registers for interrupt control
4. **Machine mode** - The most privileged RISC-V mode

---

## Terminology: Trap vs Interrupt vs Exception

These terms are often confused. Here's what they mean:

| Term | Meaning | Example |
|------|---------|---------|
| **Trap** | Generic term for any transfer to kernel | Umbrella term for all below |
| **Interrupt** | External/asynchronous event | Timer, keyboard, network |
| **Exception** | Synchronous error in code | Division by zero, invalid instruction |
| **Syscall** | Intentional trap by program | `ecall` instruction |

```
                    TRAP (generic term)
                         │
          ┌──────────────┴──────────────┐
          │                             │
     INTERRUPT                     EXCEPTION
   (asynchronous)                (synchronous)
          │                             │
   ┌──────┴──────┐              ┌───────┴───────┐
   │             │              │               │
 Timer      Keyboard        Fault           Syscall
 (CLINT)    (PLIC)       (bad addr)        (ecall)
```

**Key difference:**
- **Interrupt**: Can happen at ANY time (async) - like a phone ringing while you're cooking
- **Exception**: Happens because of the CURRENT instruction (sync) - like burning your food

---

## How Interrupts Work on RISC-V

### The Big Picture

```
Normal code running
        │
        ▼
   ┌─────────────────┐
   │ Timer fires!    │  (mtime >= mtimecmp)
   │ Hardware does:  │
   │  1. Save PC to mepc
   │  2. Save cause to mcause
   │  3. Disable interrupts
   │  4. Jump to mtvec
   └────────┬────────┘
            │
            ▼
   ┌─────────────────┐
   │ trap_entry:     │  (our assembly code)
   │  1. Save all registers
   │  2. Call C handler
   │  3. Restore registers
   │  4. mret (return)
   └────────┬────────┘
            │
            ▼
   Resume normal code
```

### Key CSRs (Control and Status Registers)

| CSR | Name | Purpose |
|-----|------|---------|
| `mstatus` | Machine Status | Global interrupt enable (MIE bit) |
| `mtvec` | Machine Trap Vector | Address of trap handler |
| `mie` | Machine Interrupt Enable | Which interrupts are enabled |
| `mip` | Machine Interrupt Pending | Which interrupts are waiting |
| `mcause` | Machine Cause | Why we trapped (interrupt/exception code) |
| `mepc` | Machine Exception PC | Where to return after trap |
| `mscratch` | Machine Scratch | Scratch register for trap handler |

### Enabling Timer Interrupts

```c
// 1. Set up trap handler address
write_csr(mtvec, trap_entry);

// 2. Schedule when timer should fire
write_mtimecmp(read_mtime() + interval);

// 3. Enable timer interrupt specifically
set_csr(mie, MIE_MTIE);  // bit 7

// 4. Enable interrupts globally
set_csr(mstatus, MSTATUS_MIE);  // bit 3
```

---

## CLINT (Core Local Interruptor)

The CLINT provides timer and software interrupts for each hart (hardware thread).

### Memory Map (QEMU virt)

| Address | Register | Description |
|---------|----------|-------------|
| `0x02000000` | msip | Software interrupt pending |
| `0x02004000` | mtimecmp | Timer compare (64-bit) |
| `0x0200BFF8` | mtime | Current time counter (64-bit) |

### How the Timer Works

```
mtime:    Counts up continuously (at 10 MHz on QEMU)
mtimecmp: When mtime >= mtimecmp, interrupt fires!

Timeline:
─────────────────────────────────────────────────►
     │              │              │
     └── mtimecmp   └── mtimecmp   └── mtimecmp
         (interrupt!)   (interrupt!)   (interrupt!)

To get periodic interrupts:
  In handler: mtimecmp = mtime + interval
```

---

## How Does `trap_handler` Get Called?

You might wonder: "No one calls `trap_handler()` in the C code - how does it run?"

The answer: **the CPU hardware calls it** (via our assembly wrapper).

### The Connection

```asm
# In start.S during initialization:
la      t0, trap_entry      # Load address of trap_entry
csrw    mtvec, t0           # Write to mtvec CSR
                            # "When ANY trap happens, jump to trap_entry"
```

This tells the CPU: "Whenever something happens (timer, fault, etc.), jump to `trap_entry`"

### The Call Chain

```
1. We write trap_entry address to mtvec CSR
   csrw mtvec, trap_entry    ← "When something happens, jump HERE"

2. Timer fires! Hardware automatically does:
   - Saves PC to mepc (so we know where to return)
   - Saves cause to mcause (so we know WHY)
   - Disables interrupts (MSTATUS.MIE = 0)
   - Jumps to address in mtvec (our trap_entry)

3. trap_entry (assembly) runs:
   - Saves all registers to memory
   - call trap_handler       ← HERE is where C function is called!
   - Restores all registers from memory
   - mret (return to interrupted code)
```

### Visual Flow

```
Your Code                          Interrupt System
─────────                          ────────────────
    │
    │  x = 5
    │  y = 10
    │                              ┌─────────────────┐
    │                              │ mtvec points to │
    │                              │ trap_entry addr │
    │                              └────────┬────────┘
    │                                       │
    ├─── TIMER FIRES! ─────────────────────►│
    │    (hardware jumps to mtvec)          │
    │                              ┌────────▼────────┐
    │                              │ trap_entry:     │
    │                              │   save regs     │
    │                              │   call trap_handler ◄── C function!
    │                              │   restore regs  │
    │                              │   mret          │
    │                              └────────┬────────┘
    │◄──────────────────────────────────────┘
    │
    │  z = x + y  ← continues exactly where it left off
    ▼
```

---

## Why Save All Registers?

This is **critical** for correct interrupt handling.

### The Problem

When an interrupt fires, your code stops mid-execution. The CPU registers contain important values:

```c
void calculate() {
    int x = 5;           // x might be in register a0
    int y = 10;          // y might be in register a1
    int z = x + y;       // About to execute...
    
    // ← TIMER INTERRUPT FIRES HERE!
    // CPU jumps to trap_entry
    // trap_handler() runs, uses a0 and a1 for ITS work
    // If we didn't save registers, a0 and a1 would be destroyed!
    // z would be garbage when we return
}
```

### Without Saving Registers (BROKEN)

```
Before interrupt:  a0=5, a1=10
                   ↓
            [interrupt fires]
                   ↓
Handler runs:      a0=???, a1=??? (used for printing, etc.)
                   ↓
            [return from interrupt]
                   ↓
After interrupt:   a0=???, a1=???  ← CORRUPTED!
z = a0 + a1 = GARBAGE
```

### With Saving Registers (CORRECT)

```
Before interrupt:  a0=5, a1=10
                   ↓
            [interrupt fires]
                   ↓
Save to memory:    trap_frame[a0]=5, trap_frame[a1]=10
                   ↓
Handler runs:      a0=???, a1=??? (free to use)
                   ↓
Restore from mem:  a0=5, a1=10
                   ↓
            [return from interrupt]
                   ↓
After interrupt:   a0=5, a1=10  ← PRESERVED!
z = 5 + 10 = 15 ✓
```

### The Trap Frame

We reserve memory (called "trap frame") to save all 31 registers:

```
Trap Frame Layout (256 bytes):
┌────────────┬─────────┐
│ Offset 0   │ x1 (ra) │
│ Offset 8   │ x3 (gp) │
│ Offset 16  │ x4 (tp) │
│ Offset 24  │ x5 (t0) │
│    ...     │   ...   │
│ Offset 232 │ x31(t6) │
│ Offset 240 │ old sp  │
└────────────┴─────────┘
```

The key insight: **the interrupted code never knows it was interrupted**. From its perspective, time just "skipped" a tiny bit. This is the foundation of preemptive multitasking in operating systems.

---

## Code Walkthrough

### start.S - Entry Point

```asm
_start:
    csrw mie, zero          # Disable all interrupts
    la   sp, _stack_top     # Set up stack
    
    la   t0, trap_entry     # Set trap handler address
    csrw mtvec, t0
    
    call main               # Initialize timer, enable interrupts
```

### start.S - Trap Handler

```asm
trap_entry:
    # 1. Save all 31 registers (x1-x31) to memory
    csrrw sp, mscratch, sp  # Swap sp with scratch
    sd    x1, 0(sp)         # Save ra
    sd    x5, 8(sp)         # Save t0
    ...
    
    # 2. Call C handler
    call trap_handler
    
    # 3. Restore all registers
    ld    x1, 0(sp)
    ...
    
    # 4. Return from trap
    mret                    # Restores PC from mepc, re-enables interrupts
```

### main.c - Timer Setup

```c
void main(void) {
    // Schedule first interrupt (1 second from now)
    write_mtimecmp(read_mtime() + TIMER_INTERVAL);
    
    // Enable timer interrupt
    set_csr(mie, MIE_MTIE);
    
    // Enable global interrupts
    set_csr(mstatus, MSTATUS_MIE);
    
    // Wait for interrupts
    while (1) asm volatile ("wfi");
}
```

### main.c - Interrupt Handler

```c
void trap_handler(void) {
    uint64_t mcause = read_csr(mcause);
    
    if (mcause & (1UL << 63)) {
        // Interrupt (high bit set)
        if ((mcause & 0xFF) == 7) {
            // Timer interrupt!
            timer_ticks++;
            
            // Schedule next interrupt
            write_mtimecmp(read_mtime() + TIMER_INTERVAL);
        }
    } else {
        // Exception - something went wrong
        // Handle or halt
    }
}
```

---

## mcause Values

### Interrupts (bit 63 = 1)

| Code | Name | Description |
|------|------|-------------|
| 3 | MSI | Machine Software Interrupt |
| 7 | MTI | Machine Timer Interrupt |
| 11 | MEI | Machine External Interrupt |

### Exceptions (bit 63 = 0)

| Code | Name | Description |
|------|------|-------------|
| 0 | Instruction address misaligned | |
| 1 | Instruction access fault | |
| 2 | Illegal instruction | |
| 3 | Breakpoint | `ebreak` instruction |
| 4 | Load address misaligned | |
| 5 | Load access fault | |
| 6 | Store address misaligned | |
| 7 | Store access fault | |
| 8 | Environment call from U-mode | `ecall` |
| 11 | Environment call from M-mode | `ecall` |

---

## RISC-V Privilege Levels

| Level | Name | Typical Use |
|-------|------|-------------|
| M | Machine | Firmware, bootloader, this example |
| S | Supervisor | OS kernel (xv6 runs here) |
| U | User | Applications |

This example runs entirely in **M-mode** (most privileged).
xv6 runs the kernel in S-mode and user programs in U-mode.

---

## Exercises

1. **Change the interval** - Make it 500ms instead of 1 second
2. **Add a software interrupt** - Write to CLINT msip register
3. **Count in the main loop** - Print how many times wfi returns
4. **Add keyboard interrupt** - UART can generate interrupts too!

---

## Next Steps

After understanding this:
1. Explore **PLIC** (Platform-Level Interrupt Controller) for external interrupts
2. Study how **xv6** handles traps (`kernel/trap.c`, `kernel/trampoline.S`)
3. Learn about **S-mode** (Supervisor mode) traps
