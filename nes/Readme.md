# NES Emulator — Learning Plan

Building an NES emulator from scratch in Go, using [fogleman/nes](https://github.com/fogleman/nes) as reference.

## Architecture Overview

```
     ines.go → Cartridge
                  ↓
Console ──────┬── CPU ←→ cpuMemory ──┬── RAM (2KB)
              │                      ├── PPU registers
              │                      ├── APU registers
              │                      ├── Controllers
              │                      └── Mapper → Cartridge PRG/CHR/SRAM
              │
              ├── PPU ←→ ppuMemory ──┬── Mapper (CHR)
              │         renders →     ├── Nametables (2KB)
              │         Palette       └── Palette RAM
              │
              ├── APU ──→ FilterChain → audio channel
              │
              └── Mapper (various) → Cartridge banks
```

The main loop ratio: **1 CPU cycle : 3 PPU cycles : 1 APU cycle**

## Learning Phases

### Phase 1 — Data structures (no dependencies)

| # | File | Lines | What to learn |
|---|------|-------|---------------|
| 1 | `palette.go` | ~24 | Static 64-entry NES color table (RGBA). Pure data. |
| 2 | `cartridge.go` | ~33 | ROM data model: PRG-ROM, CHR-ROM, SRAM, mapper/mirror/battery fields. |
| 3 | `ines.go` | ~84 | Parse iNES (.nes) file format: 16-byte header → mapper, mirroring, PRG/CHR banks. **Test immediately with a real ROM.** |
| 4 | `controller.go` | ~45 | NES joypad: serial shift register with strobe latch. Reads 8 buttons sequentially. |
| 5 | `filter.go` | ~57 | First-order IIR audio filters (high-pass, low-pass). Standalone DSP math. |

**Milestone:** Load a .nes ROM and print header info (mapper, PRG/CHR sizes, mirroring).

---

### Phase 2 — Memory architecture & first mapper

| # | File | Lines | What to learn |
|---|------|-------|---------------|
| 6 | `memory.go` | ~134 | `Memory` interface + `MirrorAddress`. Address bus routing: RAM, PPU regs, APU regs, mapper. Stub PPU/APU parts initially. |
| 7 | `mapper.go` | ~38 | `Mapper` interface: `Read`, `Write`, `Step`. Factory function dispatches by mapper number. |
| 8 | `mapper2.go` | ~70 | NROM/UxROM (mapper 0 & 2): switchable first PRG bank, fixed last bank. Enough for simple ROMs. |

**Milestone:** Memory bus reads/writes route correctly. Can read bytes from a mapper-0 ROM.

---

### Phase 3 — CPU (the 6502)

| # | File | Lines | What to learn |
|---|------|-------|---------------|
| 9 | `cpu.go` | ~975 | 13 addressing modes, 256-entry instruction table, all official opcodes. ~400 lines are tables, ~300 are simple opcode handlers. |

Build incrementally:
1. Addressing modes (Immediate, ZeroPage, Absolute, etc.)
2. `Step()` — fetch/decode/execute cycle
3. Opcodes group by group: loads → stores → arithmetic → branches → stack → jumps

**Milestone:** Pass [nestest.nes](https://www.qmtpro.com/~nes/misc/nestest.nes) CPU test (compare log output against known-good trace).

---

### Phase 4 — PPU (graphics)

| # | File | Lines | What to learn |
|---|------|-------|---------------|
| 10 | `ppu.go` | ~744 | The hardest subsystem. VRAM addressing, scroll registers, background tiles, sprite evaluation, scanline timing, NMI generation. |

Build incrementally:
1. PPU registers (`$2000`–`$2007`, `$4014` OAM DMA)
2. Background rendering (nametable fetch → pattern table → palette → pixel)
3. Sprite rendering (OAM evaluation, 8 sprites per scanline limit)
4. Scrolling (coarse/fine X/Y, mid-frame scroll changes)
5. NMI timing (vblank start at scanline 241)

**Milestone:** See tiles on screen. A simple mapper-0 game (like Donkey Kong) renders.

---

### Phase 5 — Console integration

| # | File | Lines | What to learn |
|---|------|-------|---------------|
| 11 | `console.go` | ~156 | Wire CPU + PPU + Mapper + Controllers. The main step loop: `CPU.Step()` → run PPU 3× and APU 1× per CPU cycle. |

Fill in `cpuMemory` and `ppuMemory` fully now.

**Milestone:** A game runs and is playable with keyboard input.

---

### Phase 6 — Audio

| # | File | Lines | What to learn |
|---|------|-------|---------------|
| 12 | `apu.go` | ~866 | 5 channels: 2× Pulse (square wave + sweep + envelope), Triangle, Noise, DMC (sample playback). Frame counter drives length/envelope/sweep. Lookup-table mixer. |

Implement one channel at a time: Pulse 1 → Pulse 2 → Triangle → Noise → DMC.

**Milestone:** Games have sound.

---

### Phase 7 — More mappers (add as needed for specific games)

| # | File | Lines | Games unlocked |
|---|------|-------|----------------|
| 13 | `mapper3.go` | ~70 | CNROM — CHR bank switching |
| 14 | `mapper7.go` | ~64 | AxROM — single-screen mirroring (Battletoads) |
| 15 | `mapper1.go` | ~205 | MMC1 — Zelda, Metroid, Mega Man 2 |
| 16 | `mapper4.go` | ~234 | MMC3 — Super Mario Bros 3, Kirby's Adventure |
| 17 | `mapper40.go` | ~77 | Pirate FDS conversions |
| 18 | `mapper225.go` | ~85 | Multicart |

These 6 mappers cover ~85% of all NES games.

---

## File Dependency Graph

```
palette.go ─────────────────────── (leaf)
filter.go ──────────────────────── (leaf)
cartridge.go ───────────────────── (leaf)
controller.go ──────────────────── (leaf)
ines.go ────────→ cartridge
memory.go ──────→ console, cartridge
mapper*.go ─────→ cartridge, memory (some need console/cpu/ppu)
cpu.go ─────────→ memory
ppu.go ─────────→ memory, console, palette
apu.go ─────────→ console, cpu, filter
console.go ─────→ ALL (orchestrator)
```

## Resources

* [6502 Assembly Crash Course](https://www.youtube.com/playlist?list=PLgvDB6LWam2WvoFvh8tlUqbqw92qWM0aP)

* [fogleman/nes source](https://github.com/fogleman/nes) — reference implementation
* [NES Documentation (PDF)](http://nesdev.com/NESDoc.pdf) — hardware reference
* [NESDev Wiki](http://wiki.nesdev.com/w/index.php/NES_reference_guide) — comprehensive reference
* [6502 CPU Reference](http://www.obelisk.me.uk/6502/reference.html) — opcode details
* [NES Emulator (YouTube)](https://www.youtube.com/playlist?list=PLrOv9FMX8xJHqMvSGB_9G9nZZ_4IgteYf)
* [NES Emulator (YouTube)](https://www.youtube.com/watch?v=Dq_cpyrYI70)

* [6502 Emulator in Python](https://www.youtube.com/playlist?list=PLlEgNdBJEO-kHbqZyO_BHdxulFndTvptC)
* [6502 CPU Emulator in C++](https://www.youtube.com/playlist?list=PLLwK93hM93Z13TRzPx9JqTIn33feefl37)
