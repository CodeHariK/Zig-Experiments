# NES CPU (Ricoh 2A03 / MOS 6502) Instruction Set Architecture

The NES CPU uses a Ricoh 2A03 chip, which is an exact clone of the MOS Technology 6502 microprocessor (lacking only the BCD - Binary Coded Decimal circuitry). 

## Does the NES have 256 instructions?
Technically, **no**. The NES uses 1-byte opcodes, meaning there are 256 *possible* opcode slots (0x00 to 0xFF) in its encoding space. However:
- There are only **56 unique standard instructions**.
- When combined with different addressing modes, these form **151 official opcodes**.
- The remaining **105 opcodes** are "unofficial" or "illegal" opcodes. Some combine multiple instructions, some act as alternate `NOP`s (No Operation), and some crash/halt the CPU (often called `KIL` or `JAM` instructions).

---

## 1. Addressing Modes
The 6502 supports 13 addressing modes to access memory and registers.

| Mode | Assembler Syntax | Size (Bytes) | Description |
|---|---|---|---|
| **Implicit/Implied** | `INX` | 1 | Target is implied by the instruction (e.g., registers, flags). |
| **Accumulator** | `ASL A` | 1 | Operates directly on the Accumulator register. |
| **Immediate** | `LDA #$10` | 2 | The operand is exactly the next byte in memory. |
| **Zero Page** | `LDA $10` | 2 | Accesses the first 256 bytes of memory ($0000 - $00FF). Faster than Absolute mode. |
| **Zero Page, X** | `LDA $10,X` | 2 | Addresses zero page with X offset (Wraps around at 0xFF). |
| **Zero Page, Y** | `LDX $10,Y` | 2 | Addresses zero page with Y offset (Only used with LDX/STX). |
| **Relative** | `BEQ *+4` | 2 | Used for branching; offset is a signed byte from -128 to +127 bytes away from PC. |
| **Absolute** | `LDA $1234` | 3 | Uses a full 16-bit address to access anywhere in memory. |
| **Absolute, X** | `LDA $1234,X` | 3 | Absolute address plus X register. |
| **Absolute, Y** | `LDA $1234,Y` | 3 | Absolute address plus Y register. |
| **Indirect** | `JMP ($1234)` | 3 | Jumps to the address stored at the 16-bit pointer. (Only used by `JMP`). |
| **Indexed Indirect (X)** | `LDA ($20,X)` | 2 | Pointer in zero page, offset by X before reading address. |
| **Indirect Indexed (Y)** | `LDA ($20),Y` | 2 | Reads pointer from zero page, then adds Y to the resulting 16-bit address. |

---

## 2. Official Instructions (56 total)

### Load / Store Operations
- **LDA**: Load Accumulator
- **LDX**: Load X Register
- **LDY**: Load Y Register
- **STA**: Store Accumulator
- **STX**: Store X Register
- **STY**: Store Y Register

### Register Transfers
- **TAX**: Transfer A to X
- **TAY**: Transfer A to Y
- **TXA**: Transfer X to A
- **TYA**: Transfer Y to A
- **TXS**: Transfer X to Stack Pointer
- **TSX**: Transfer Stack Pointer to X

### Stack Operations
*(Stack memory on the NES is hardcoded from $0100 to $01FF)*
- **PHA**: Push Accumulator on Stack
- **PHP**: Push Processor Status on Stack
- **PLA**: Pull Accumulator from Stack
- **PLP**: Pull Processor Status from Stack

### Logical Operations
- **AND**: Logical AND with Accumulator
- **EOR**: Logical Exclusive OR with Accumulator
- **ORA**: Logical Inclusive OR with Accumulator
- **BIT**: Bit Test (Tests bits in memory with A)

### Arithmetic Operations
- **ADC**: Add with Carry
- **SBC**: Subtract with Carry
- **CMP**: Compare Accumulator
- **CPX**: Compare X Register
- **CPY**: Compare Y Register

### Increments / Decrements
- **INC**: Increment Memory
- **INX**: Increment X Register
- **INY**: Increment Y Register
- **DEC**: Decrement Memory
- **DEX**: Decrement X Register
- **DEY**: Decrement Y Register

### Shifts / Rotates
- **ASL**: Arithmetic Shift Left (Shifts bit 7 into Carry, bit 0 becomes 0)
- **LSR**: Logical Shift Right (Shifts bit 0 into Carry, bit 7 becomes 0)
- **ROL**: Rotate Left (Rotates Carry into bit 0, bit 7 to Carry)
- **ROR**: Rotate Right (Rotates Carry into bit 7, bit 0 to Carry)

### Jumps / Subroutines
- **JMP**: Jump to another location (changes PC)
- **JSR**: Jump to Subroutine (saves return address to stack, then sets PC)
- **RTS**: Return from Subroutine (pulls return address from stack)
- **RTI**: Return from Interrupt (pulls processor flags and PC from stack)

### Branches
- **BCC**: Branch if Carry Clear (C=0)
- **BCS**: Branch if Carry Set (C=1)
- **BEQ**: Branch if Equal / Zero Flag Set (Z=1)
- **BMI**: Branch if Minus / Negative Flag Set (N=1)
- **BNE**: Branch if Not Equal / Zero Flag Clear (Z=0)
- **BPL**: Branch if Positive / Negative Flag Clear (N=0)
- **BVC**: Branch if Overflow Clear (V=0)
- **BVS**: Branch if Overflow Set (V=1)

### Status Flag Operations
- **CLC**: Clear Carry Flag
- **CLD**: Clear Decimal Mode Flag (Valid instruction, but decimal mode is disabled on NES)
- **CLI**: Clear Interrupt Disable Flag
- **CLV**: Clear Overflow Flag
- **SEC**: Set Carry Flag
- **SED**: Set Decimal Mode Flag
- **SEI**: Set Interrupt Disable Flag

### System Operations
- **BRK**: Force Interrupt (Break)
- **NOP**: No Operation

---

## 3. Unofficial / Illegal Opcodes (105 total)
When writing a highly compatible emulator, these undocumented opcodes must be implemented, as several popular games (and lots of homebrew/demos) use them to optimize execution speed. They effectively combination-lock multiple instructions into a single memory byte step due to overlapping transistors in the 6502 design.

### Common Working Illegal Instructions:
- **ALR (ASR)**: `AND` then `LSR`.
- **ANC**: `AND` memory, set Carry based on bit 7.
- **ARR**: `AND` then `ROR`.
- **AXS (SBX)**: `CMP` and `DEX` at once.
- **LAX**: `LDA` and `LDX` simultaneously.
- **SAX**: Stores A `AND` X into memory.
- **DCP**: `DEC` memory, then `CMP` with A.
- **ISC (ISB)**: `INC` memory, then `SBC`.
- **RLA**: `ROL` memory, then `AND` with Accumulator.
- **RRA**: `ROR` memory, then `ADC` into Accumulator.
- **SLO**: `ASL` memory, then `ORA` into Accumulator.
- **SRE**: `LSR` memory, then `EOR` into Accumulator.
- **SKB (DOP)**: Double-byte `NOP` (skips the next byte).
- **SKW (TOP)**: Triple-byte `NOP` (skips the next two bytes).

### Halting Opcodes (KIL/JAM):
There are several opcodes (e.g., `$02, $12, $22, $32, $42, $52, $62, $72, $92, $B2, $D2, $F2`) that lock up the 6502 CPU entirely. When executed, the address bus goes to `0xFFFF` and the CPU halts. Only a hardware system reset can recover the processor from these states.
