package src

import (
	"encoding/gob"
	"fmt"
)

// Mapper translates CPU and PPU memory reads/writes to the cartridge
type Mapper interface {
	Read(address uint16) byte
	Write(address uint16, value byte)
	Step()
	Save(encoder *gob.Encoder) error
	Load(decoder *gob.Decoder) error
}

// NewMapper creates a new mapper based on the cartridge's Mapper ID
func NewMapper(console *Console) (Mapper, error) {
	cartridge := console.Cartridge
	if cartridge.Mapper != 0 {
		fmt.Printf("DEBUG: NewMapper called with mapper %v (type %T)\n", cartridge.Mapper, cartridge.Mapper)
	}
	switch cartridge.Mapper {
	case 0: // NROM refers to Mapper 0 / 2 without banking
		return NewMapper0(cartridge), nil
	case 1: // MMC1
		return NewMapper1(cartridge), nil
	case 3: // CNROM
		return NewMapper3(cartridge), nil
	case 4: // MMC3
		return NewMapper4(console, cartridge), nil
	case 196: // MMC3 bootleg
		return NewMapper196(console, cartridge), nil
	}
	return nil, fmt.Errorf("unsupported mapper: %d", cartridge.Mapper)
}

// Mapper0 represents the simplest NES cartridge (NROM) like Super Mario Bros.
// No bank-switching.
type Mapper0 struct {
	cartridge *Cartridge
	prgBanks  int
	prgBank1  int
	prgBank2  int
}

func NewMapper0(cartridge *Cartridge) *Mapper0 {
	prgBanks := len(cartridge.PRG) / 0x4000
	return &Mapper0{
		cartridge: cartridge,
		prgBanks:  prgBanks,
		prgBank1:  0,
		prgBank2:  prgBanks - 1,
	}
}

func (m *Mapper0) Step() {}

func (m *Mapper0) Read(address uint16) byte {
	switch {
	case address < 0x2000:
		// CHR-ROM / CHR-RAM
		return m.cartridge.CHR[address]
	case address >= 0x8000:
		// PRG-ROM
		address = address - 0x8000
		bank := address / 0x4000
		offset := address % 0x4000
		if bank == 0 {
			return m.cartridge.PRG[m.prgBank1*0x4000+int(offset)]
		}
		return m.cartridge.PRG[m.prgBank2*0x4000+int(offset)]
	case address >= 0x6000:
		// SRAM
		return m.cartridge.SRAM[address-0x6000]
	default:
		return 0
	}
}

func (m *Mapper0) Write(address uint16, value byte) {
	switch {
	case address < 0x2000:
		// CHR-RAM check
		// Allow writes to CHR if using Mapper 0; if it was ROM the game wouldn't write to it anyway
		if len(m.cartridge.CHR) > 0 {
			m.cartridge.CHR[address] = value
		}
	case address >= 0x6000 && address < 0x8000:
		// SRAM
		m.cartridge.SRAM[address-0x6000] = value
	}
}

func (m *Mapper0) Save(encoder *gob.Encoder) error {
	encoder.Encode(m.prgBanks)
	encoder.Encode(m.prgBank1)
	encoder.Encode(m.prgBank2)
	return nil
}

func (m *Mapper0) Load(decoder *gob.Decoder) error {
	decoder.Decode(&m.prgBanks)
	decoder.Decode(&m.prgBank1)
	decoder.Decode(&m.prgBank2)
	return nil
}
