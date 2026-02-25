# Interrupts

* [Ben Eater: Hardware interrupts](https://www.youtube.com/watch?v=DlEa8kd7n3Q)
* [Ben Eater: Interrupt handling](https://www.youtube.com/watch?v=oOYA-jsWTmc)
* [BitLemon: How Interrupts Work in Modern Computers](https://www.youtube.com/watch?v=G7bqvpAw7HE)
* [CPU Interrupts - Computerphile](https://www.youtube.com/watch?v=tGMSARJk7cA)
* [Core Dumped: How Hardware Assist Software When Multitasking](https://www.youtube.com/watch?v=1HHeyUVz43k)
* [Core Dumped: How CPUs Interact with So Many Different Devices](https://www.youtube.com/watch?v=tadUeiNe5-g)

* https://en.wikipedia.org/wiki/Interrupt
* https://en.wikipedia.org/wiki/Interrupts_in_65xx_processors

# Hardware Interrupts: Then and Now

## What is an Interrupt?
At the most basic level, an **Interrupt** is a physical electrical signal sent to the CPU telling it, *"Stop what you are doing right now, save your place, handle this urgent event, and then go back to what you were doing."*

Instead of the CPU constantly wasting cycles asking devices, *"Did you push a button yet? Did you finish drawing the screen yet?"* (a process called **Polling**), the CPU can just run the main program loop. When an external device needs attention, it pulls a physical pin on the CPU chip low (sending voltage), which "interrupts" the CPU.

---

## How the 6502 Processed Interrupts

The MOS 6502 has two primary hardware interrupt pins:
1. **IRQ (Interrupt Request):** A standard, "maskable" interrupt. The programmer can tell the CPU to temporarily ignore these by setting the `I` (Interrupt Disable) flag. On the NES, this was often used by advanced game cartridges to trigger audio events or split-screen scrolling at precise times.
2. **NMI (Non-Maskable Interrupt):** An absolute priority interrupt that *cannot* be ignored. On the NES, the PPU (Graphics Chip) triggers an NMI exactly 60 times a second when it finishes drawing a frame to the TV (the VBLANK period). This is how games know it's safe to update the graphics for the next frame!

### The 6502 Interrupt Sequence
When the 6502 receives an interrupt signal (like an NMI), it automatically performs a hardwired 7-cycle sequence:

1. **Finish Current Instruction:** It finishes the exact instruction it is on right now.
2. **Push PC to Stack:** It automatically pushes the 16-bit Program Counter (where it currently is in the code) onto the Stack (Page 1).
3. **Push Status to Stack:** It automatically pushes the Processor Status Register (flags like Zero, Carry, Negative) onto the Stack.
4. **Set Interrupt Disable:** It sets the `I` flag to `1` so another generic IRQ can't interrupt this interrupt.
5. **Jump to Vector:** It loads a new 16-bit Program Counter address from a hardcoded location at the very top of memory (for NMI, it always checks `$FFFA` and `$FFFB`).
6. **Execute ISR:** It runs the code located at that address—this is called the **Interrupt Service Routine (ISR)**.
7. **Return:** At the end of the ISR, the programmer writes an `RTI` (Return from Interrupt) instruction. This pulls the Status and original Program Counter back off the stack, and the CPU seamlessly resumes the original game code as if nothing happened.

---

## How Interrupts Evolved in Modern CPUs (e.g., RISC-V)

While the core concept—stopping execution, saving state, jumping to a handler, and returning—remains identical today, modern processors like **RISC-V** have evolved significantly to handle complex, multi-core, operating-system-driven environments.

### 1. Privilege Levels (User vs. Machine Mode)
The 6502 was a single-tasking CPU—all code ran with full access to everything. Modern CPUs run Operating Systems (like Linux) that isolate user programs (like a web browser) from the hardware. 
In RISC-V, interrupts usually force a "Context Switch" from **User Mode** up to **Machine/Supervisor Mode**. The OS takes over, handles the interrupt, and decides if it should return to the same user program or switch to a different one.

### 2. Advanced Registers (CSRs) instead of the Stack
The 6502 auto-pushed your state to the slow memory stack. This took 7 clock cycles, which was relatively fast in 1975! 
RISC-V aims for incredible speed. Instead of pushing to RAM automatically, RISC-V copies the Program Counter into a dedicated lightning-fast internal hardware register called `mepc` (Machine Exception Program Counter), and the status into `mstatus`. The software handler then decides *if* it needs to save registers to the stack.

### 3. PLIC / CLINT (Advanced Controllers)
The 6502 only had two interrupt pins. If three different devices (audio, keyboard, disk drive) were all wired to the IRQ pin, the 6502's software had to manually poll all three devices to ask, *"Which one of you pulled the pin?"*

Modern RISC-V chips include massive external interrupt routing blocks like the **PLIC** (Platform-Level Interrupt Controller) and **CLINT** (Core Local Interruptor). 
* The PLIC can manage hundreds of different external devices.
* It assigns different priorities to different devices.
* It supports "Vectored" interrupts, meaning instead of the CPU jumping to one single ISR address and having to figure out who knocked, the hardware immediately jumps the CPU to the specific code for the exact device that triggered the interrupt.
* In a multi-core RISC-V chip, the PLIC can intelligently route an interrupt to whichever CPU core is currently least busy!
