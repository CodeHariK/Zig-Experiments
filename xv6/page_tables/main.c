/*
 * main.c - RISC-V Page Table / Virtual Memory Example
 *
 * Demonstrates:
 *   - Sv39 page table setup
 *   - Identity mapping with gigapages
 *   - Switching from M-mode to S-mode
 *   - Page fault handling
 *
 * Memory layout (QEMU virt):
 *   0x10000000 - UART
 *   0x80000000 - RAM start (kernel loaded here)
 *   0x80080000 - Page tables
 */

#include <stdint.h>

// ============================================================================
// UART (for output)
// ============================================================================

#define UART0_BASE 0x10000000UL
#define UART_THR 0
#define UART_LSR 5
#define UART_LSR_TX_EMPTY (1 << 5)

static inline void uart_putc(char c) {
    while ((*(volatile uint8_t *)(UART0_BASE + UART_LSR) & UART_LSR_TX_EMPTY) == 0)
        ;
    *(volatile uint8_t *)(UART0_BASE + UART_THR) = c;
}

static void uart_puts(const char *s) {
    while (*s)
        uart_putc(*s++);
}

static void uart_put_hex(uint64_t n) {
    uart_puts("0x");
    for (int i = 60; i >= 0; i -= 4) {
        int d = (n >> i) & 0xF;
        uart_putc(d < 10 ? '0' + d : 'a' + d - 10);
    }
}

static void uart_put_hex_short(uint64_t n) {
    uart_puts("0x");
    // Skip leading zeros
    int started = 0;
    for (int i = 60; i >= 0; i -= 4) {
        int d = (n >> i) & 0xF;
        if (d != 0 || started || i == 0) {
            uart_putc(d < 10 ? '0' + d : 'a' + d - 10);
            started = 1;
        }
    }
}

static void uart_put_dec(uint64_t n) {
    if (n == 0) {
        uart_putc('0');
        return;
    }
    char buf[20];
    int i = 0;
    while (n > 0) {
        buf[i++] = '0' + (n % 10);
        n /= 10;
    }
    while (i > 0)
        uart_putc(buf[--i]);
}

// ============================================================================
// CSR Access Macros
// ============================================================================

#define read_csr(csr) ({                      \
    uint64_t __v;                             \
    asm volatile ("csrr %0, " #csr : "=r"(__v)); \
    __v;                                      \
})

#define write_csr(csr, val) ({                \
    asm volatile ("csrw " #csr ", %0" :: "r"(val)); \
})

// ============================================================================
// Page Table Constants
// ============================================================================

#define PAGE_SIZE       4096
#define PAGE_SHIFT      12

// Sv39: 39-bit virtual address, 3-level page table
// VPN[2] | VPN[1] | VPN[0] | Offset
// 9 bits | 9 bits | 9 bits | 12 bits

#define LEVELS          3
#define PTE_PER_PAGE    512     // 2^9 entries per page table

// Page Table Entry bits
#define PTE_V   (1UL << 0)      // Valid
#define PTE_R   (1UL << 1)      // Read
#define PTE_W   (1UL << 2)      // Write
#define PTE_X   (1UL << 3)      // Execute
#define PTE_U   (1UL << 4)      // User accessible
#define PTE_G   (1UL << 5)      // Global
#define PTE_A   (1UL << 6)      // Accessed
#define PTE_D   (1UL << 7)      // Dirty

// Gigapage size (1 GB = 2^30 bytes)
#define GIGAPAGE_SIZE   (1UL << 30)
#define GIGAPAGE_MASK   (GIGAPAGE_SIZE - 1)

// Page table location (must be page-aligned)
// We place it after our code at 0x80080000
#define PAGE_TABLE_ROOT 0x80080000UL

// ============================================================================
// Page Table Entry Helpers
// ============================================================================

// Create a PTE that points to a physical address with given flags
// For leaf entries (gigapages), physical address must be gigapage-aligned
static inline uint64_t make_leaf_pte(uint64_t pa, uint64_t flags) {
    // PPN is bits [53:10] of the PTE
    // PA >> 12 gives us the full PPN, then shift left by 10 to position it
    return ((pa >> PAGE_SHIFT) << 10) | flags | PTE_V;
}

// Create a PTE that points to another page table (non-leaf)
static inline uint64_t make_table_pte(uint64_t pa) {
    // Non-leaf: V=1, R=W=X=0
    return ((pa >> PAGE_SHIFT) << 10) | PTE_V;
}

// Extract physical address from PTE
static inline uint64_t pte_to_pa(uint64_t pte) {
    return ((pte >> 10) & 0xFFFFFFFFFFFUL) << PAGE_SHIFT;
}

// Check if PTE is a leaf (has R, W, or X set)
static inline int pte_is_leaf(uint64_t pte) {
    return (pte & (PTE_R | PTE_W | PTE_X)) != 0;
}

// ============================================================================
// Memory Utilities
// ============================================================================

static void memset64(uint64_t *dst, uint64_t val, uint64_t count) {
    for (uint64_t i = 0; i < count; i++) {
        dst[i] = val;
    }
}

// ============================================================================
// Page Table Setup (called from assembly before entering S-mode)
// ============================================================================

// This function is called from start.S in Machine mode.
// It builds identity-mapped page tables and returns the root table address.
uint64_t setup_page_tables(void) {
    uart_puts("\r\n");
    uart_puts("================================================\r\n");
    uart_puts("  Setting up Sv39 Page Tables\r\n");
    uart_puts("================================================\r\n\r\n");

    // Get pointer to root page table
    uint64_t *root = (uint64_t *)PAGE_TABLE_ROOT;

    uart_puts("Page table root at: ");
    uart_put_hex(PAGE_TABLE_ROOT);
    uart_puts("\r\n\r\n");

    // Clear the root page table (512 entries * 8 bytes = 4096 bytes)
    uart_puts("Clearing page table...\r\n");
    memset64(root, 0, PTE_PER_PAGE);

    // ========================================================================
    // Create Identity Mapping using Gigapages (1 GB each)
    // ========================================================================
    //
    // Sv39 virtual address: | VPN[2] | VPN[1] | VPN[0] | Offset |
    // For a gigapage, we put a leaf entry directly in the root table (level 2).
    // VPN[2] selects which 1GB region.
    //
    // Physical address ranges we need to map:
    //   0x00000000 - 0x3FFFFFFF (1 GB) - Contains UART at 0x10000000
    //   0x80000000 - 0xBFFFFFFF (1 GB) - RAM (our code and data)
    //
    // VPN[2] = VA[38:30], so:
    //   VA 0x00000000 has VPN[2] = 0
    //   VA 0x80000000 has VPN[2] = 2 (0x80000000 >> 30 = 2)
    //
    // ========================================================================

    uart_puts("Creating identity-mapped gigapages:\r\n");

    // Map first 1 GB (0x00000000 - 0x3FFFFFFF) - contains UART
    // VPN[2] = 0
    uint64_t pte0 = make_leaf_pte(0x00000000UL, PTE_R | PTE_W);
    root[0] = pte0;
    uart_puts("  [0] VA 0x00000000-0x3FFFFFFF -> PA 0x00000000 (UART region)\r\n");
    uart_puts("      PTE: ");
    uart_put_hex(pte0);
    uart_puts("\r\n");

    // Map RAM region (0x80000000 - 0xBFFFFFFF)
    // VPN[2] = 2
    uint64_t pte2 = make_leaf_pte(0x80000000UL, PTE_R | PTE_W | PTE_X);
    root[2] = pte2;
    uart_puts("  [2] VA 0x80000000-0xBFFFFFFF -> PA 0x80000000 (RAM/kernel)\r\n");
    uart_puts("      PTE: ");
    uart_put_hex(pte2);
    uart_puts("\r\n");

    uart_puts("\r\nPage table setup complete!\r\n");
    uart_puts("Returning root table address for satp...\r\n\r\n");

    return PAGE_TABLE_ROOT;
}

// ============================================================================
// Supervisor-mode Exception Cause Codes (scause values)
// ============================================================================

#define SCAUSE_INSTR_MISALIGNED     0
#define SCAUSE_INSTR_ACCESS_FAULT   1
#define SCAUSE_ILLEGAL_INSTR        2
#define SCAUSE_BREAKPOINT           3
#define SCAUSE_LOAD_MISALIGNED      4
#define SCAUSE_LOAD_ACCESS_FAULT    5
#define SCAUSE_STORE_MISALIGNED     6
#define SCAUSE_STORE_ACCESS_FAULT   7
#define SCAUSE_ECALL_U              8
#define SCAUSE_ECALL_S              9
#define SCAUSE_INSTR_PAGE_FAULT     12
#define SCAUSE_LOAD_PAGE_FAULT      13
#define SCAUSE_STORE_PAGE_FAULT     15

static const char *exception_names[] = {
    [SCAUSE_INSTR_MISALIGNED]   = "Instruction address misaligned",
    [SCAUSE_INSTR_ACCESS_FAULT] = "Instruction access fault",
    [SCAUSE_ILLEGAL_INSTR]      = "Illegal instruction",
    [SCAUSE_BREAKPOINT]         = "Breakpoint",
    [SCAUSE_LOAD_MISALIGNED]    = "Load address misaligned",
    [SCAUSE_LOAD_ACCESS_FAULT]  = "Load access fault",
    [SCAUSE_STORE_MISALIGNED]   = "Store address misaligned",
    [SCAUSE_STORE_ACCESS_FAULT] = "Store access fault",
    [SCAUSE_ECALL_U]            = "Environment call from U-mode",
    [SCAUSE_ECALL_S]            = "Environment call from S-mode",
    [10]                        = "Reserved",
    [11]                        = "Reserved",
    [SCAUSE_INSTR_PAGE_FAULT]   = "Instruction page fault",
    [SCAUSE_LOAD_PAGE_FAULT]    = "Load page fault",
    [14]                        = "Reserved",
    [SCAUSE_STORE_PAGE_FAULT]   = "Store/AMO page fault",
};

// ============================================================================
// Trap Handler (called from assembly)
// ============================================================================

void trap_handler(void) {
    uint64_t scause = read_csr(scause);
    uint64_t sepc = read_csr(sepc);
    uint64_t stval = read_csr(stval);

    // Check if it's an interrupt (high bit set) or exception
    if (scause & (1UL << 63)) {
        // Interrupt
        uint64_t cause = scause & 0xFF;
        uart_puts("\r\n[INTERRUPT] cause=");
        uart_put_dec(cause);
        uart_puts("\r\n");
    } else {
        // Exception
        uart_puts("\r\n========================================\r\n");
        uart_puts("EXCEPTION OCCURRED!\r\n");
        uart_puts("========================================\r\n");

        uart_puts("scause: ");
        uart_put_dec(scause);
        if (scause < 16 && exception_names[scause]) {
            uart_puts(" (");
            uart_puts(exception_names[scause]);
            uart_puts(")");
        }
        uart_puts("\r\n");

        uart_puts("sepc:   ");
        uart_put_hex(sepc);
        uart_puts(" (faulting instruction)\r\n");

        uart_puts("stval:  ");
        uart_put_hex(stval);

        // For page faults, stval contains the faulting virtual address
        if (scause == SCAUSE_INSTR_PAGE_FAULT ||
            scause == SCAUSE_LOAD_PAGE_FAULT ||
            scause == SCAUSE_STORE_PAGE_FAULT) {
            uart_puts(" (faulting virtual address)");
        }
        uart_puts("\r\n");

        // For page faults, provide more details
        if (scause == SCAUSE_LOAD_PAGE_FAULT) {
            uart_puts("\r\n-> Attempted to READ from unmapped address!\r\n");
        } else if (scause == SCAUSE_STORE_PAGE_FAULT) {
            uart_puts("\r\n-> Attempted to WRITE to unmapped address!\r\n");
        } else if (scause == SCAUSE_INSTR_PAGE_FAULT) {
            uart_puts("\r\n-> Attempted to EXECUTE from unmapped address!\r\n");
        }

        uart_puts("========================================\r\n");
        uart_puts("Halting.\r\n");

        // Halt on exception
        while (1)
            asm volatile ("wfi");
    }
}

// ============================================================================
// Test Functions
// ============================================================================

// Test reading from mapped memory
static void test_mapped_read(void) {
    uart_puts("Test 1: Reading from mapped memory (should succeed)\r\n");
    uart_puts("  Reading from 0x80000000 (kernel code)...\r\n");

    volatile uint32_t *ptr = (volatile uint32_t *)0x80000000UL;
    uint32_t val = *ptr;

    uart_puts("  Value at 0x80000000: ");
    uart_put_hex_short(val);
    uart_puts(" [OK]\r\n\r\n");
}

// Test writing to mapped memory
static void test_mapped_write(void) {
    uart_puts("Test 2: Writing to mapped memory (should succeed)\r\n");

    // Write to a safe location (somewhere in our data section)
    extern uint64_t test_variable;
    uart_puts("  Writing 0xDEADBEEF to test_variable...\r\n");

    test_variable = 0xDEADBEEFCAFEBABEUL;

    uart_puts("  Read back: ");
    uart_put_hex(test_variable);
    if (test_variable == 0xDEADBEEFCAFEBABEUL) {
        uart_puts(" [OK]\r\n\r\n");
    } else {
        uart_puts(" [FAIL]\r\n\r\n");
    }
}

// Test UART access (shows our device mapping works)
static void test_uart_access(void) {
    uart_puts("Test 3: UART access at 0x10000000 (should succeed)\r\n");
    uart_puts("  If you see this, UART mapping works! [OK]\r\n\r\n");
}

// Test reading from unmapped memory (will cause page fault)
static void test_unmapped_read(void) {
    uart_puts("Test 4: Reading from UNMAPPED memory (will cause PAGE FAULT)\r\n");
    uart_puts("  Attempting to read from 0x40000000 (not mapped)...\r\n");

    volatile uint32_t *ptr = (volatile uint32_t *)0x40000000UL;
    uint32_t val = *ptr;  // This will fault!

    // Should never reach here
    uart_puts("  Value: ");
    uart_put_hex_short(val);
    uart_puts("\r\n");
}

// ============================================================================
// Global test variable (in BSS)
// ============================================================================

uint64_t test_variable;

// ============================================================================
// Main (called after paging is enabled)
// ============================================================================

void main(void) {
    uart_puts("\r\n");
    uart_puts("================================================\r\n");
    uart_puts("  Running in Supervisor Mode with Paging!\r\n");
    uart_puts("================================================\r\n\r\n");

    // Display current satp value
    uint64_t satp = read_csr(satp);
    uart_puts("satp register: ");
    uart_put_hex(satp);
    uart_puts("\r\n");

    uint64_t mode = (satp >> 60) & 0xF;
    uint64_t asid = (satp >> 44) & 0xFFFF;
    uint64_t ppn = satp & 0xFFFFFFFFFFFUL;

    uart_puts("  MODE: ");
    uart_put_dec(mode);
    uart_puts(" (");
    if (mode == 0) uart_puts("Bare - no translation");
    else if (mode == 8) uart_puts("Sv39 - 39-bit virtual");
    else if (mode == 9) uart_puts("Sv48 - 48-bit virtual");
    else uart_puts("Unknown");
    uart_puts(")\r\n");

    uart_puts("  ASID: ");
    uart_put_dec(asid);
    uart_puts("\r\n");

    uart_puts("  PPN:  ");
    uart_put_hex_short(ppn);
    uart_puts(" (root table at PA ");
    uart_put_hex_short(ppn << 12);
    uart_puts(")\r\n\r\n");

    // Run tests
    uart_puts("--- Running Memory Access Tests ---\r\n\r\n");

    test_mapped_read();
    test_mapped_write();
    test_uart_access();

    uart_puts("All mapped memory tests passed!\r\n\r\n");

    uart_puts("--- Testing Page Fault ---\r\n\r\n");
    uart_puts("About to trigger a page fault by reading unmapped memory.\r\n");
    uart_puts("The trap handler will catch this and display the fault info.\r\n\r\n");

    test_unmapped_read();

    // Should never reach here
    uart_puts("ERROR: Unexpectedly continued after page fault!\r\n");
}
