package src

import "log"

// Memory interface — anything the CPU reads/writes through
type Memory interface {
	Read(address uint16) byte
	Write(address uint16, value byte)
}

// SimpleMemory provides a basic NES CPU memory map for mapper 0 (NROM).
// This is enough to run simple ROMs and test the CPU.
//
// NES CPU Memory Map:
//   $0000-$07FF  2KB internal RAM
//   $0800-$1FFF  Mirrors of RAM
//   $2000-$3FFF  PPU registers (stubbed)
//   $4000-$4017  APU & I/O registers (stubbed)
//   $4018-$5FFF  Normally disabled (stubbed)
//   $6000-$7FFF  Cartridge SRAM
//   $8000-$BFFF  PRG-ROM lower bank (16KB)
//   $C000-$FFFF  PRG-ROM upper bank (16KB, or mirror of lower if only 1 bank)
type SimpleMemory struct {
	RAM  [2048]byte // 2KB internal RAM
	Cart *Cartridge
}

func NewSimpleMemory(cart *Cartridge) *SimpleMemory {
	return &SimpleMemory{Cart: cart}
}

func (m *SimpleMemory) Read(address uint16) byte {
	switch {
	case address < 0x2000:
		return m.RAM[address%0x0800]
	case address < 0x4000:
		// PPU registers — stub, return 0
		return 0
	case address < 0x4020:
		// APU & I/O registers — stub, return 0
		return 0
	case address < 0x6000:
		// expansion ROM — stub
		return 0
	case address < 0x8000:
		// SRAM
		return m.Cart.SRAM[address-0x6000]
	case address >= 0x8000:
		// PRG-ROM
		return m.readPRG(address)
	default:
		log.Fatalf("unhandled cpu memory read at address: 0x%04X", address)
		return 0
	}
}

func (m *SimpleMemory) Write(address uint16, value byte) {
	switch {
	case address < 0x2000:
		m.RAM[address%0x0800] = value
	case address < 0x4000:
		// PPU registers — stub, ignore
	case address < 0x4020:
		// APU & I/O registers — stub, ignore
	case address < 0x6000:
		// expansion ROM — stub, ignore
	case address < 0x8000:
		// SRAM
		m.Cart.SRAM[address-0x6000] = value
	case address >= 0x8000:
		// PRG-ROM is read-only for mapper 0, ignore writes
	default:
		log.Fatalf("unhandled cpu memory write at address: 0x%04X", address)
	}
}

// readPRG handles NROM mapping:
//   - 1 PRG bank (16KB): $8000-$BFFF and $C000-$FFFF both map to the same bank
//   - 2 PRG banks (32KB): $8000-$BFFF = first bank, $C000-$FFFF = second bank
func (m *SimpleMemory) readPRG(address uint16) byte {
	addr := int(address - 0x8000)
	if len(m.Cart.PRG) == 16384 {
		// Mirror: 16KB ROM appears at both $8000 and $C000
		addr = addr % 16384
	}
	return m.Cart.PRG[addr]
}
