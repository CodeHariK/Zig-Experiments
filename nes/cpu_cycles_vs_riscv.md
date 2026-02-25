# 6502 Clock Cycles vs. Modern Architectures (e.g., RISC-V)

The biggest difference between the NES's **Ricoh 2A03 (6502)** and modern chips like **RISC-V** comes down to microarchitecture design philosophy—specifically **CISC vs. RISC** and pipelining techniques.

## Why the 6502 Takes Multiple Cycles per Instruction

The 6502, released in 1975, does *not* utilize a modern instruction pipeline. Every single step of an instruction must be executed sequentially over multiple physical clock ticks due to hardware limitations (such as having an 8-bit data bus).

For example, an instruction like `STA $1234` (Store Accumulator to Absolute Memory) requires reading a 1-byte opcode (`$8D`), a 2-byte address (`$34`, `$12`), and performing a write back to that memory space. 

This takes the CPU at least 4 physical clock ticks just to shuffle the bytes back and forth across the wires:
1. **Cycle 1:** Fetch the opcode (`$8D`) from memory.
2. **Cycle 2:** Decode the opcode and fetch the low byte of the address (`$34`).
3. **Cycle 3:** Fetch the high byte of the address (`$12`).
4. **Cycle 4:** Read/write the actual data to the constructed memory address (`$1234`).
5. **Additional Cycles:** Depending on the instruction, the Arithmetic Logic Unit (ALU) might process data, or branching penalties might occur.

There is no way for the 6502 to complete a complex operation like `ADC $1234` in a single cycle, because the processor physically cannot fetch the opcode, fetch the 16-bit target address, fetch the target data from RAM, and execute the mathematical addition simultaneously.

## How RISC-V Achieves 1 Cycle per Instruction

Modern RISC architectures (Reduced Instruction Set Computers) like RISC-V or ARM achieve an average of ~1.0 cycles per instruction (CPI) using specialized techniques:

1. **Wider Buses & Fixed-Length Instructions:** In RISC-V, standard instructions are exactly 32 bits wide. The CPU can fetch an *entire* instruction (opcode, destination register, source registers, and small immediate values) in a single read from memory.
2. **Pipelining:** The CPU is divided into stages (e.g., Fetch → Decode → Execute → Memory → Writeback). While instruction #3 is executing, instruction #4 is decoding, and instruction #5 is being fetched. This "assembly line" means that even though a single instruction might take 5 clock cycles from start to finish, **one instruction finishes its journey and retires every single clock cycle.**
3. **Load/Store Architecture:** RISC architectures force you to use specific `LOAD` and `STORE` instructions to interact with memory. All arithmetic operations (like `ADD` or `MUL`) only ever happen between internal CPU registers, which are extremely fast and predictable. 

By contrast, the 6502's instructions are highly variable. Some are 1 byte long (taking 2 cycles), while others are 3 bytes long and require complex pointer lookups from RAM (taking up to 7 cycles).

## Clock Speed (MHz) vs. Instruction Rate (IPC)

When we say the NES CPU runs at **~1.79 MHz**, we are referring to the raw pulse of the quartz oscillator crystal driving the chip, ticking 1,789,773 times per second.

Because an average 6502 instruction takes roughly **4 clock cycles** to complete:
* The CPU runs at **~1.79 Million clock cycles per second.**
* But it only executes about **450,000 instructions per second.**

If you designed a 1.79 MHz RISC-V processor, thanks to pipelining, it would execute nearly **1.79 Million instructions per second!** 

This is why raw clock speed (MHz/GHz) alone doesn't tell you how fast a CPU is—you must also know its **IPC (Instructions Per Cycle)**.
