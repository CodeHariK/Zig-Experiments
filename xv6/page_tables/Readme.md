# RISC-V Page Tables and Memory Management

This example demonstrates **virtual memory** and **page tables** on RISC-V Sv39.

## Quick Start

```bash
make        # Build
make run    # Run (see page table setup and address translation!)
```

Press `Ctrl-A` then `X` to exit QEMU.

---

## What This Demonstrates

1. **Sv39 Page Tables** - The 3-level page table format
2. **Address Translation** - How virtual addresses become physical
3. **Identity Mapping** - Map virtual = physical for simplicity
4. **satp CSR** - Enabling paging in Supervisor mode
5. **Page Faults** - What happens with invalid accesses

---

## Why Do We Need Virtual Memory?

### The Problem Without Virtual Memory

```
Without Virtual Memory:

Process A            Physical RAM
┌─────────────┐      ┌─────────────┐
│ Code at     │ ───► │ 0x80000000  │  ← A's code
│ 0x80000000  │      │             │
└─────────────┘      │             │
                     │             │
Process B            │             │
┌─────────────┐      │             │
│ Code at     │ ───► │ 0x80100000  │  ← B's code
│ 0x80100000  │      └─────────────┘

Problems:
1. Each process needs different addresses in their code
2. Processes can read/write each other's memory
3. A program can crash the whole system
```

### The Solution: Virtual Memory

```
With Virtual Memory:

Process A                              Physical RAM
┌─────────────┐                        ┌─────────────┐
│ Code at     │ ──► Page ──────────►   │ 0x80000000  │
│ 0x00010000  │     Table A            │             │
└─────────────┘                        │             │
                                       │             │
Process B                              │             │
┌─────────────┐                        │             │
│ Code at     │ ──► Page ──────────►   │ 0x80100000  │
│ 0x00010000  │     Table B            └─────────────┘

Benefits:
1. Every process can use the SAME virtual addresses
2. Processes are isolated from each other
3. OS controls what memory each process can access
```

---

## RISC-V Address Translation

### Virtual Address (Sv39 - 39-bit virtual addresses)

RISC-V Sv39 uses a **3-level page table** with 39-bit virtual addresses:

```
63        39 38        30 29        21 20        12 11         0
┌──────────┬────────────┬────────────┬────────────┬────────────┐
│  unused  │   VPN[2]   │   VPN[1]   │   VPN[0]   │   Offset   │
│  (25 bits - must be   │  9 bits    │  9 bits    │  9 bits    │  12 bits   │
│   sign extension)     │            │            │            │            │
└──────────┴────────────┴────────────┴────────────┴────────────┘
           │            │            │            │
           │            │            │            └─► Index within 4KB page
           │            │            └──────────────► Level 0 page table index
           │            └───────────────────────────► Level 1 page table index
           └────────────────────────────────────────► Level 2 page table index
```

- **VPN** = Virtual Page Number
- Each level has 512 entries (2^9)
- Pages are 4KB (2^12 bytes)

### Page Table Entry (PTE) Format

Each page table entry is 64 bits:

```
63        54 53        28 27        19 18        10 9   8  7  6  5  4  3  2  1  0
┌───────────┬────────────────────────────────────┬─────┬──┬──┬──┬──┬──┬──┬──┬──┐
│  Reserved │              PPN                   │ RSW │ D│ A│ G│ U│ X│ W│ R│ V│
│  (10 bits)│  (44 bits physical page number)    │     │  │  │  │  │  │  │  │  │
└───────────┴────────────────────────────────────┴─────┴──┴──┴──┴──┴──┴──┴──┴──┘
```

**Permission Bits:**

| Bit | Name | Meaning |
|-----|------|---------|
| V | Valid | Entry is valid |
| R | Read | Page can be read |
| W | Write | Page can be written |
| X | Execute | Page can be executed |
| U | User | Accessible in User mode |
| G | Global | Mapping exists in all address spaces |
| A | Accessed | Page has been read |
| D | Dirty | Page has been written |

**Important Rules:**
- If `R=0`, `W=0`, `X=0`: This is a **pointer** to next level page table
- If any of `R`, `W`, or `X` is 1: This is a **leaf** entry (actual mapping)
- `W=1` requires `R=1` (can't have write-only pages)

### Translation Process (3-Level Walk)

```
Virtual Address: 0x0000_0000_8020_1234
                           ↓
Step 1: Extract VPN[2] = 2 (bits 38:30)
        satp.PPN ──► Root Page Table
                     Entry[2] ──► Level 1 table

Step 2: Extract VPN[1] = 1 (bits 29:21)
        Level 1 table
        Entry[1] ──► Level 0 table

Step 3: Extract VPN[0] = 1 (bits 20:12)
        Level 0 table
        Entry[1] ──► Physical Page Number

Step 4: Combine PPN + Offset
        Physical Address = PPN << 12 | Offset(0x234)
                         = 0x8020_1234
```

### Visual Translation Example

```
                    satp CSR
                    ┌──────────┐
                    │ PPN: 0x80│ ← Points to root page table at 0x80000
                    └────┬─────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │         Root (Level 2)              │ @ Physical 0x80000000
        │  [0] -> invalid                     │
        │  [1] -> invalid                     │
        │  [2] -> PPN=0x80001, V=1, RWX=0    │ ← Pointer to Level 1
        │  ...                                │
        │  [511] -> invalid                   │
        └──────────────┬─────────────────────┘
                       │ VPN[2]=2
                       ▼
        ┌────────────────────────────────────┐
        │         Level 1                     │ @ Physical 0x80001000
        │  [0] -> invalid                     │
        │  [1] -> PPN=0x80002, V=1, RWX=0    │ ← Pointer to Level 0
        │  ...                                │
        └──────────────┬─────────────────────┘
                       │ VPN[1]=1
                       ▼
        ┌────────────────────────────────────┐
        │         Level 0                     │ @ Physical 0x80002000
        │  [0] -> invalid                     │
        │  [1] -> PPN=0x80200, V=1, RWX=111  │ ← LEAF: maps to 0x80200000
        │  ...                                │
        └─────────────────────────────────────┘

        Final: VA 0x80201234 → PA 0x80201234 (identity mapped)
```

---

## The satp CSR (Supervisor Address Translation and Protection)

```
63   60 59         44 43                                  0
┌──────┬─────────────┬─────────────────────────────────────┐
│ MODE │    ASID     │                PPN                  │
│4 bits│   16 bits   │              44 bits                │
└──────┴─────────────┴─────────────────────────────────────┘
```

| MODE Value | Name | Description |
|------------|------|-------------|
| 0 | Bare | No translation (physical = virtual) |
| 8 | Sv39 | 39-bit virtual addresses, 3-level page table |
| 9 | Sv48 | 48-bit virtual addresses, 4-level page table |
| 10 | Sv57 | 57-bit virtual addresses, 5-level page table |

**ASID** (Address Space ID): Allows TLB entries from different processes to coexist.

**PPN**: Physical Page Number of the root page table.

### Enabling Paging

```c
// Build page table at physical address 0x80080000
uint64_t root_table = 0x80080000;

// Calculate satp value:
// MODE = 8 (Sv39)
// ASID = 0
// PPN = root_table >> 12
uint64_t satp_val = (8UL << 60) | (root_table >> 12);

// Write to satp (this enables paging!)
write_csr(satp, satp_val);

// Flush TLB
sfence_vma();
```

---

## Identity Mapping

For this example, we use **identity mapping** where virtual address = physical address.

```
Identity Map:
    Virtual 0x80000000 → Physical 0x80000000
    Virtual 0x80001000 → Physical 0x80001000
    Virtual 0x10000000 → Physical 0x10000000 (UART)
    ...

Why use identity mapping?
1. Code doesn't need to change addresses after enabling paging
2. Stack pointer still valid
3. Simplest way to enable paging
```

### Gigapage Mapping (1 GB pages)

For simplicity, this example uses **gigapages** (1 GB = 2^30 bytes).

With Sv39, if VPN[2] points to a leaf entry (has R/W/X bits), it maps 1 GB at once:

```
Normal 4KB page:
    VPN[2] → Level 1 table → Level 0 table → 4KB page
    
Gigapage (1 GB):
    VPN[2] → 1GB physical region (leaf entry at level 2!)
    
This means ONE page table entry can map a full gigabyte!
Very efficient for identity mapping large regions.
```

---

## Machine Mode vs Supervisor Mode

This example switches from **M-mode** (Machine) to **S-mode** (Supervisor):

| Mode | CSRs | Page Tables | Use Case |
|------|------|-------------|----------|
| M-mode | mcsr, mstatus, etc. | No (physical only) | Firmware, bootloader |
| S-mode | scsr, sstatus, etc. | Yes (satp controls) | OS kernel |
| U-mode | Limited | Yes | User applications |

### Why S-mode for Page Tables?

- Page tables are controlled by the **satp** CSR
- **satp is an S-mode register** (not accessible in M-mode for paging)
- M-mode always uses physical addresses
- The kernel runs in S-mode and manages page tables

### Switching M-mode → S-mode

```asm
# Set Previous Privilege to Supervisor (mstatus.MPP = 1)
li      t0, (1 << 11)      # MPP[12:11] = 01 = S-mode
csrs    mstatus, t0

# Set return address
la      t1, supervisor_entry
csrw    mepc, t1

# Return to S-mode (mret uses mepc and MPP)
mret
```

---

## Code Walkthrough

### start.S - Page Table Setup

```asm
_start:
    # 1. Disable interrupts
    csrw    mie, zero
    
    # 2. Set up stack (physical address, still in M-mode)
    la      sp, _stack_top
    
    # 3. Build page tables
    call    setup_page_tables
    
    # 4. Set up satp (but don't enable yet!)
    la      t0, _page_table_root
    srli    t0, t0, 12          # Get PPN
    li      t1, (8 << 60)       # Sv39 mode
    or      t0, t0, t1
    csrw    satp, t0
    
    # 5. Switch to S-mode (paging will activate)
    # ... set mstatus.MPP = 01 (S-mode)
    # ... mret to supervisor_entry
```

### main.c - Page Table Construction

```c
void setup_page_tables(void) {
    // Get page table memory
    uint64_t *root = (uint64_t *)PAGE_TABLE_ROOT;
    
    // Clear page tables
    memset(root, 0, PAGE_SIZE);
    
    // Map first 1GB (0x00000000 - 0x3FFFFFFF) - UART at 0x10000000
    root[0] = make_pte(0x00000000, PTE_R | PTE_W | PTE_V);  // Gigapage
    
    // Map RAM region (0x80000000 - 0xBFFFFFFF)
    root[2] = make_pte(0x80000000, PTE_R | PTE_W | PTE_X | PTE_V);  // Gigapage
}
```

---

## Page Faults

When translation fails, the CPU generates a **page fault exception**:

| scause | Exception |
|--------|-----------|
| 12 | Instruction page fault |
| 13 | Load page fault |
| 15 | Store page fault |

**stval** contains the faulting virtual address.

```c
void trap_handler(void) {
    uint64_t scause = read_csr(scause);
    uint64_t stval = read_csr(stval);
    
    if (scause == 13) {
        // Load page fault
        uart_puts("Page fault reading address: ");
        uart_put_hex(stval);
    }
}
```

---

## Memory Layout

```
Physical Memory Map (QEMU virt):
┌────────────────────────────────────────┐
│ 0x00000000 - 0x0FFFFFFF                │ ← Various hardware
├────────────────────────────────────────┤
│ 0x10000000  UART                       │ ← Serial console
├────────────────────────────────────────┤
│ 0x80000000 - 0x87FFFFFF  RAM (128MB)   │ ← Our code + data
│   0x80000000  Kernel code (.text)      │
│   0x8000XXXX  Kernel data (.data)      │
│   0x80080000  Page tables              │
│   0x80090000  Stack                    │
└────────────────────────────────────────┘

After enabling Sv39 (identity mapped):
    VA 0x10000000 → PA 0x10000000 (UART)
    VA 0x80000000 → PA 0x80000000 (Code)
    VA 0x80080000 → PA 0x80080000 (Page tables)
```

---

## Key RISC-V Instructions

| Instruction | Description |
|-------------|-------------|
| `sfence.vma` | Flush TLB (after changing page tables) |
| `csrw satp, x` | Write to satp (changes address translation) |
| `sret` | Return from S-mode trap |
| `mret` | Return from M-mode trap (can change privilege) |

---

## TLB (Translation Lookaside Buffer)

The TLB caches recent address translations:

```
Without TLB:
    Every memory access → 3 page table lookups → SLOW!
    
With TLB:
    First access → 3 lookups → cache result
    Next access → TLB hit → FAST!
```

**Important:** After modifying page tables, you MUST flush the TLB:

```asm
sfence.vma          # Flush entire TLB
sfence.vma a0       # Flush entries for address in a0
sfence.vma a0, a1   # Flush entries for address a0, ASID a1
```

---

## Exercises

1. **Add a page fault handler** - Catch and print invalid accesses
2. **Map user space** - Create a separate mapping for 0x00000000 region with U bit
3. **Implement demand paging** - Only map pages when accessed
4. **Use 4KB pages** - Replace gigapages with full 3-level mapping
5. **Multiple address spaces** - Use ASID to have different mappings

---

## Common Bugs

1. **Forgetting sfence.vma** - TLB has stale entries after page table change
2. **Wrong PPN calculation** - Remember: PPN = physical_address >> 12
3. **Invalid permission combinations** - W=1 requires R=1
4. **Sign extension** - Bits 63:39 must match bit 38 (sign extension)
5. **Misaligned page tables** - Must be 4KB aligned

---

## References

- [RISC-V Privileged Spec](https://riscv.org/technical/specifications/) - Chapter 4 (Virtual Memory)
- [xv6-riscv vm.c](https://github.com/mit-pdos/xv6-riscv/blob/riscv/kernel/vm.c)
- [xv6 book](https://pdos.csail.mit.edu/6.828/2023/xv6/book-riscv-rev3.pdf) - Chapter 3

---

## Next Steps

After understanding this:
1. Study xv6 `vm.c` and `trampoline.S`
2. Implement per-process page tables
3. Learn about copy-on-write (COW) pages
4. Explore kernel/user address space separation
