/*
 * main.c - RISC-V Timer Interrupt Example
 *
 * Demonstrates:
 *   - CLINT (Core Local Interruptor) timer
 *   - Machine-mode trap handling
 *   - Periodic timer interrupts
 *
 * On QEMU virt: Timer runs at 10MHz (10,000,000 ticks/second)
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
  while ((*(volatile uint8_t *)(UART0_BASE + UART_LSR) & UART_LSR_TX_EMPTY) ==
         0)
    ;
  *(volatile uint8_t *)(UART0_BASE + UART_THR) = c;
}

static void uart_puts(const char *s) {
  while (*s)
    uart_putc(*s++);
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

static void uart_put_hex(uint64_t n) {
  uart_puts("0x");
  for (int i = 60; i >= 0; i -= 4) {
    int d = (n >> i) & 0xF;
    uart_putc(d < 10 ? '0' + d : 'a' + d - 10);
  }
}

// ============================================================================
// CLINT (Core Local Interruptor) - Timer Hardware
// ============================================================================
//
// QEMU virt machine CLINT memory map:
//   0x02000000 + 0x0000 : msip      (software interrupt pending)
//   0x02000000 + 0x4000 : mtimecmp  (timer compare - when to interrupt)
//   0x02000000 + 0xBFF8 : mtime     (current time counter)
//
// Timer frequency: 10 MHz on QEMU virt
//

#define CLINT_BASE 0x02000000UL
#define CLINT_MTIMECMP (CLINT_BASE + 0x4000)
#define CLINT_MTIME (CLINT_BASE + 0xBFF8)

// Timer frequency (10 MHz on QEMU virt)
#define TIMER_FREQ 10000000UL

// How often to fire timer interrupt (1 second)
#define TIMER_INTERVAL (TIMER_FREQ * 1)

// Read current time
static inline uint64_t read_mtime(void) {
  return *(volatile uint64_t *)CLINT_MTIME;
}

// Set timer compare value (interrupt fires when mtime >= mtimecmp)
static inline void write_mtimecmp(uint64_t value) {
  *(volatile uint64_t *)CLINT_MTIMECMP = value;
}

// ============================================================================
// CSR (Control and Status Register) Access
// ============================================================================

// Read CSR
#define read_csr(csr)                                                          \
  ({                                                                           \
    uint64_t __v;                                                              \
    asm volatile("csrr %0, " #csr : "=r"(__v));                                \
    __v;                                                                       \
  })

// Write CSR
#define write_csr(csr, val) ({ asm volatile("csrw " #csr ", %0" ::"r"(val)); })

// Set bits in CSR
#define set_csr(csr, val) ({ asm volatile("csrs " #csr ", %0" ::"r"(val)); })

// Clear bits in CSR
#define clear_csr(csr, val) ({ asm volatile("csrc " #csr ", %0" ::"r"(val)); })

// ============================================================================
// CSR Bit Definitions
// ============================================================================

// mstatus bits
#define MSTATUS_MIE (1 << 3)  // Machine Interrupt Enable
#define MSTATUS_MPIE (1 << 7) // Machine Previous Interrupt Enable

// mie (machine interrupt enable) bits
#define MIE_MTIE (1 << 7)  // Machine Timer Interrupt Enable
#define MIE_MEIE (1 << 11) // Machine External Interrupt Enable
#define MIE_MSIE (1 << 3)  // Machine Software Interrupt Enable

// mcause values
#define MCAUSE_INTERRUPT (1UL << 63) // High bit = interrupt (not exception)
#define MCAUSE_MTI 7                 // Machine Timer Interrupt

// ============================================================================
// Global State (in BSS - cleared to zero by start.S)
// ============================================================================

volatile uint64_t timer_ticks; // Count of timer interrupts
volatile uint64_t last_mtime;  // For calculating elapsed time

// ============================================================================
// Trap Handler (called from assembly)
// ============================================================================

void trap_handler(void) {
  uint64_t mcause = read_csr(mcause);
  uint64_t mepc = read_csr(mepc);

  // Check if this is an interrupt (high bit set) or exception
  if (mcause & MCAUSE_INTERRUPT) {
    // It's an interrupt
    uint64_t cause = mcause & 0xFF;

    if (cause == MCAUSE_MTI) {
      // Timer interrupt!
      timer_ticks++;

      uint64_t now = read_mtime();
      uint64_t elapsed = now - last_mtime;
      last_mtime = now;

      uart_puts("\r\n[TIMER INTERRUPT #");
      uart_put_dec(timer_ticks);
      uart_puts("] mtime=");
      uart_put_dec(now);
      uart_puts(" elapsed=");
      uart_put_dec(elapsed);
      uart_puts(" ticks\r\n");

      // Schedule next timer interrupt
      write_mtimecmp(now + TIMER_INTERVAL);

    } else {
      uart_puts("\r\n[UNKNOWN INTERRUPT] cause=");
      uart_put_hex(cause);
      uart_puts("\r\n");
    }
  } else {
    // It's an exception (fault)
    uart_puts("\r\n[EXCEPTION] mcause=");
    uart_put_hex(mcause);
    uart_puts(" mepc=");
    uart_put_hex(mepc);
    uart_puts("\r\n");

    // For exceptions, we need to advance mepc to skip the faulting instruction
    // Otherwise we'll trap forever on the same instruction
    // (For simplicity, we just halt here)
    uart_puts("HALTING due to exception.\r\n");
    while (1)
      asm volatile("wfi");
  }
}

// ============================================================================
// Main
// ============================================================================

void main(void) {
  uart_puts("\r\n");
  uart_puts("================================================\r\n");
  uart_puts("  RISC-V Timer Interrupt Demo\r\n");
  uart_puts("================================================\r\n\r\n");

  // Show CLINT addresses
  uart_puts("CLINT base:     ");
  uart_put_hex(CLINT_BASE);
  uart_puts("\r\n");
  uart_puts("CLINT mtime:    ");
  uart_put_hex(CLINT_MTIME);
  uart_puts("\r\n");
  uart_puts("CLINT mtimecmp: ");
  uart_put_hex(CLINT_MTIMECMP);
  uart_puts("\r\n");
  uart_puts("Timer freq:     ");
  uart_put_dec(TIMER_FREQ);
  uart_puts(" Hz\r\n");
  uart_puts("Interval:       ");
  uart_put_dec(TIMER_INTERVAL / TIMER_FREQ);
  uart_puts(" second(s)\r\n\r\n");

  // Read initial time
  uint64_t now = read_mtime();
  last_mtime = now;
  uart_puts("Current mtime:  ");
  uart_put_dec(now);
  uart_puts("\r\n\r\n");

  // Schedule first timer interrupt
  uart_puts("Setting mtimecmp to trigger in 1 second...\r\n");
  write_mtimecmp(now + TIMER_INTERVAL);

  // Enable timer interrupt in mie
  uart_puts("Enabling machine timer interrupt (MIE.MTIE)...\r\n");
  set_csr(mie, MIE_MTIE);

  // Enable global interrupts in mstatus
  uart_puts("Enabling global interrupts (MSTATUS.MIE)...\r\n");
  set_csr(mstatus, MSTATUS_MIE);

  uart_puts("\r\nWaiting for interrupts... (Ctrl-A X to exit QEMU)\r\n");
  uart_puts("You should see a timer interrupt every second.\r\n\r\n");

  // Main loop - just wait for interrupts
  while (1) {
    // wfi = Wait For Interrupt (low power wait)
    asm volatile("wfi");

    // After waking from interrupt, print a dot to show we're alive
    uart_putc('.');
  }
}
