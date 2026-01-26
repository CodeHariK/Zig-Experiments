package systeminterface

import (
	"fmt"
)

const (
	MEMORY_MAP_ROM_START = 0x10000000
	MEMORY_MAP_ROM_END   = 0x1FFFFFFF
	MEMORY_MAP_RAM_START = 0x20000000
	MEMORY_MAP_RAM_END   = 0x2FFFFFFF
)

type MMIO_DEVICE interface {
	Read(addr uint64) (uint64, error)
	Write(addr uint64, value uint64) error
}

type SystemInterface struct {
	rom *ROM_Device
	ram *RAM_Device
}

func NewSystemInterface(rom *ROM_Device, ram *RAM_Device) *SystemInterface {
	si := &SystemInterface{}
	si.rom = rom
	si.ram = ram
	return si
}

func (si *SystemInterface) Read(addr uint64) (uint64, error) {
	if (addr & 0b11) != 0 {
		return 0, fmt.Errorf("Unaligned read at address 0x%X",
			ToHexString(addr, 32))
	}

	wordAddr := (addr & 0x0FFFFFFF) >> 2 // word address

	if (addr & MEMORY_MAP_ROM_START) == MEMORY_MAP_ROM_START {
		return si.rom.Read(wordAddr)
	}
	if (addr & MEMORY_MAP_RAM_START) == MEMORY_MAP_RAM_START {
		return si.ram.Read(wordAddr)
	}

	return 0, nil
}

func (si *SystemInterface) Write(addr uint64, value uint64) error {
	if (addr & 0b11) != 0 {
		return fmt.Errorf("Unaligned write at address 0x%X (value 0x%X)",
			ToHexString(addr, 32), ToHexString(value, 32))
	}

	wordAddr := (addr & 0x0FFFFFFF) >> 2 // word address

	if (addr & MEMORY_MAP_RAM_START) == MEMORY_MAP_RAM_START {
		return si.ram.Write(wordAddr, value)
	}

	return nil
}
