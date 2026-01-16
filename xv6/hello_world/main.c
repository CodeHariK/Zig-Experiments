/*
 * main.c - Bare metal RISC-V Hello World with Keyboard Input
 *
 * This prints "Hello, World!" to the UART serial port and reads keyboard input.
 * On QEMU's "virt" machine, the UART is a 16550-compatible device
 * mapped at address 0x10000000.
 */

#include <stdint.h>

// ============================================================================
// UART Hardware Interface (16550 compatible)
// ============================================================================
// See: https://www.lammertbies.nl/comm/info/serial-uart

#define UART0_BASE 0x10000000UL

// UART register offsets
#define UART_THR 0 // Transmit Holding Register (write)
#define UART_RBR 0 // Receive Buffer Register (read) - same address as THR!
#define UART_IER 1 // Interrupt Enable Register
#define UART_FCR 2 // FIFO Control Register (write)
#define UART_ISR 2 // Interrupt Status Register (read)
#define UART_LCR 3 // Line Control Register
#define UART_LSR 5 // Line Status Register

// Line Status Register (LSR) bits
#define UART_LSR_RX_READY (1 << 0) // Data available to read
#define UART_LSR_TX_EMPTY (1 << 5) // Transmitter empty, can write

// Read a UART register
static inline uint8_t uart_read(int reg) {
  return *(volatile uint8_t *)(UART0_BASE + reg);
}

// Write to a UART register
static inline void uart_write(int reg, uint8_t val) {
  *(volatile uint8_t *)(UART0_BASE + reg) = val;
}

// ============================================================================
// UART Output Functions
// ============================================================================

// Wait until UART is ready to transmit, then send a character
void uart_putc(char c) {
  while ((uart_read(UART_LSR) & UART_LSR_TX_EMPTY) == 0)
    ;
  uart_write(UART_THR, c);
}

// Print a null-terminated string
void uart_puts(const char *s) {
  while (*s) {
    uart_putc(*s++);
  }
}

// Print a number in hexadecimal
void uart_put_hex(uint64_t n) {
  uart_puts("0x");
  for (int i = 60; i >= 0; i -= 4) {
    int digit = (n >> i) & 0xF;
    uart_putc(digit < 10 ? '0' + digit : 'a' + digit - 10);
  }
}

// Print a number in decimal
void uart_put_dec(int64_t n) {
  if (n < 0) {
    uart_putc('-');
    n = -n;
  }
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
  while (i > 0) {
    uart_putc(buf[--i]);
  }
}

// ============================================================================
// UART Input Functions
// ============================================================================

// Check if a character is available to read (non-blocking)
int uart_has_char(void) { return uart_read(UART_LSR) & UART_LSR_RX_READY; }

// Read a character from UART (blocking - waits until char available)
char uart_getc(void) {
  while (!uart_has_char())
    ;
  return uart_read(UART_RBR);
}

// Read a character if available, return -1 if not (non-blocking)
int uart_getc_nonblock(void) {
  if (uart_has_char()) {
    return uart_read(UART_RBR);
  }
  return -1;
}

// Read a line into buffer (with basic line editing)
// Returns number of characters read (not including null terminator)
int uart_getline(char *buf, int maxlen) {
  int i = 0;
  while (i < maxlen - 1) {
    char c = uart_getc();

    if (c == '\r' || c == '\n') {
      // Enter pressed - end of line
      uart_puts("\r\n");
      break;
    } else if (c == 127 || c == '\b') {
      // Backspace/Delete
      if (i > 0) {
        i--;
        uart_puts("\b \b"); // Erase character on screen
      }
    } else if (c >= 32 && c < 127) {
      // Printable character
      buf[i++] = c;
      uart_putc(c); // Echo
    }
    // Ignore other control characters
  }
  buf[i] = '\0';
  return i;
}

// ============================================================================
// Main Program
// ============================================================================

void main(void) {
  uart_puts("\r\n");
  uart_puts("========================================\r\n");
  uart_puts("  Bare-Metal RISC-V Hello World\r\n");
  uart_puts("========================================\r\n");
  uart_puts("\r\n");
  uart_puts("UART base address: ");
  uart_put_hex(UART0_BASE);
  uart_puts("\r\n\r\n");

  uart_puts("Commands:\r\n");
  uart_puts("  echo  - Enter echo mode (type, see it back)\r\n");
  uart_puts("  count - Count keypresses\r\n");
  uart_puts("  hex   - Show hex codes of keys\r\n");
  uart_puts("  quit  - Exit to halt\r\n");
  uart_puts("\r\n");
  uart_puts("Press Ctrl-A then X to exit QEMU.\r\n");
  uart_puts("\r\n");

  char line[64];

  while (1) {
    uart_puts("> ");
    uart_getline(line, sizeof(line));

    // Simple command parser
    if (line[0] == 'e' && line[1] == 'c' && line[2] == 'h' && line[3] == 'o') {
      // Echo mode
      uart_puts("Echo mode (Ctrl-C to exit):\r\n");
      while (1) {
        char c = uart_getc();
        if (c == 3)
          break; // Ctrl-C
        uart_putc(c);
        if (c == '\r')
          uart_putc('\n');
      }
      uart_puts("\r\n");
    } else if (line[0] == 'c' && line[1] == 'o' && line[2] == 'u') {
      // Count mode
      uart_puts("Counting keypresses (Ctrl-C to exit):\r\n");
      int count = 0;
      while (1) {
        char c = uart_getc();
        if (c == 3)
          break; // Ctrl-C
        count++;
        uart_puts("\rCount: ");
        uart_put_dec(count);
        uart_puts("   ");
      }
      uart_puts("\r\nTotal: ");
      uart_put_dec(count);
      uart_puts(" keys\r\n");
    } else if (line[0] == 'h' && line[1] == 'e' && line[2] == 'x') {
      // Hex mode - show key codes
      uart_puts("Showing hex codes (Ctrl-C to exit):\r\n");
      while (1) {
        char c = uart_getc();
        if (c == 3)
          break; // Ctrl-C
        uart_puts("Key: ");
        if (c >= 32 && c < 127) {
          uart_putc('\'');
          uart_putc(c);
          uart_putc('\'');
        } else {
          uart_puts("   ");
        }
        uart_puts(" = 0x");
        uart_putc("0123456789ABCDEF"[(c >> 4) & 0xF]);
        uart_putc("0123456789ABCDEF"[c & 0xF]);
        uart_puts(" = ");
        uart_put_dec(c);
        uart_puts("\r\n");
      }
      uart_puts("\r\n");
    } else if (line[0] == 'q' && line[1] == 'u' && line[2] == 'i') {
      uart_puts("Halting...\r\n");
      break;
    } else if (line[0] != '\0') {
      uart_puts("Unknown command: ");
      uart_puts(line);
      uart_puts("\r\n");
    }
  }
}
