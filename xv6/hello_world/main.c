/*
 * main.c - Bare metal RISC-V Hello World
 *
 * This prints "Hello, World!" to the UART serial port.
 * On QEMU's "virt" machine, the UART is a 16550-compatible device
 * mapped at address 0x10000000.
 */

#include <stdint.h>

// UART registers for QEMU virt machine (16550 compatible)
// See: https://www.lammertbies.nl/comm/info/serial-uart
#define UART0_BASE 0x10000000UL

// UART register offsets
#define UART_THR 0 // Transmit Holding Register (write)
#define UART_RBR 0 // Receive Buffer Register (read)
#define UART_LSR 5 // Line Status Register

// Line Status Register bits
#define UART_LSR_TX_EMPTY (1 << 5) // Transmitter empty

// Read a UART register
static inline uint8_t uart_read(int reg) {
  return *(volatile uint8_t *)(UART0_BASE + reg);
}

// Write to a UART register
static inline void uart_write(int reg, uint8_t val) {
  *(volatile uint8_t *)(UART0_BASE + reg) = val;
}

// Wait until UART is ready to transmit, then send a character
void uart_putc(char c) {
  // Wait for transmit holding register to be empty
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

// Entry point called from start.S
void main(void) {
  uart_puts("Hello, World!\n");
  uart_puts("\n");
  uart_puts("This is bare-metal RISC-V running on QEMU.\n");
  uart_puts("UART base address: ");
  uart_put_hex(UART0_BASE);
  uart_puts("\n");
  uart_puts("\nPress Ctrl-A then X to exit QEMU.\n");

  // Loop forever
  while (1) {
    // Could read input here with uart_read(UART_RBR)
  }
}
