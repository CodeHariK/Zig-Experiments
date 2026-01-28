package systeminterface

const (
	MEMORY_MAP_ROM_START = 0x10000000
	MEMORY_MAP_ROM_END   = 0x1FFFFFFF
	MEMORY_MAP_RAM_START = 0x20000000
	MEMORY_MAP_RAM_END   = 0x2FFFFFFF
)

type MEMORY_WIDTH byte

const (
	MEMORY_WIDTH_BYTE MEMORY_WIDTH = 0b000
	MEMORY_WIDTH_HALF MEMORY_WIDTH = 0b001
	MEMORY_WIDTH_WORD MEMORY_WIDTH = 0b010
)

type MMIO_DEVICE interface {
	Read(addr uint32, width MEMORY_WIDTH) (uint32, error)
	Write(addr uint32, value uint32, width MEMORY_WIDTH) error
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

func (si *SystemInterface) Read(addr uint32, width MEMORY_WIDTH) (uint32, error) {

	if (addr & MEMORY_MAP_ROM_START) == MEMORY_MAP_ROM_START {
		return si.rom.Read(addr&0x0FFFFFFF, width)
	}
	if (addr & MEMORY_MAP_RAM_START) == MEMORY_MAP_RAM_START {
		return si.ram.Read(addr&0x0FFFFFFF, width)
	}

	return 0, nil
}

func (si *SystemInterface) Write(addr uint32, value uint32, width MEMORY_WIDTH) error {

	if (addr & MEMORY_MAP_RAM_START) == MEMORY_MAP_RAM_START {
		return si.ram.Write(addr&0x0FFFFFFF, value, width)
	}

	return nil
}
