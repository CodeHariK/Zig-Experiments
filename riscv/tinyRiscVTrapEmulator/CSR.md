RISC-V Control and Status Registers (CSRs) used for trap/exception handling in Supervisor mode. Here's what each one does:

### CSR Descriptions

#### stvec (Supervisor Trap Vector Base Address)
* Holds the address of the trap handler code
* When a trap occurs (like ECALL), the CPU jumps to this address
* Can be configured in different modes (direct vs vectored)

#### sepc (Supervisor Exception Program Counter)
Saves the PC value where the trap occurred
Used by SRET to return to the interrupted code
Critical for resuming execution after handling the trap

#### scause (Supervisor Cause Register)
Indicates why the trap occurred
Examples: 8 = ECALL from U-mode, 9 = ECALL from S-mode
MSB indicates interrupt vs exception

#### sstatus (Supervisor Status Register)
Contains various mode bits and privilege information
Key bits: SIE (interrupt enable), SPIE (previous interrupt enable), SPP (previous privilege mode)
Tracks state that needs to be preserved/restored across traps

### Official RISC-V Documentation:

RISC-V Privileged Specification - The authoritative source

https://github.com/riscv/riscv-isa-manual/releases
Look for "The RISC-V Instruction Set Manual, Volume II: Privileged Architecture"
Chapter 4 covers Supervisor-Level ISA
Section 4.1 details these CSRs
Quick Reference:

https://five-embeddev.com/riscv-isa-manual/ (web-browsable version)
These CSRs are how xv6 (and any RISC-V OS) implements system calls, interrupts, and exception handling!

