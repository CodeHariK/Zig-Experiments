package systeminterface

import "fmt"

const ROM_SIZE = 1024 * 1024 / 4 // 1 MB = 1024 * 1024 bytes = 256K int32
const ROM_MASK = ROM_SIZE - 1

type ROM_Device struct {
	memory      [ROM_SIZE]uint32
	ProgramSize uint32
}

func (rd *ROM_Device) Read(addr uint32, width MEMORY_WIDTH) (uint32, error) {

	offset := addr & 0b11
	wordAddr := addr >> 2
	value := rd.memory[wordAddr&ROM_MASK]

	switch width {
	case MEMORY_WIDTH_BYTE:
		switch offset {
		case 0:
			value = (value >> 24) & 0xFF
		case 1:
			value = (value >> 16) & 0xFF
		case 2:
			value = (value >> 8) & 0xFF
		case 3:
			value = value & 0xFF
		}
	case MEMORY_WIDTH_HALF:
		switch offset & 1 {
		case 0:
			value = (value >> 16) & 0xFFFF
		case 1:
			value = value & 0xFFFF
		default:
			return 0, fmt.Errorf("Unaligned halfword read at address 0x%X", addr)
		}
	case MEMORY_WIDTH_WORD:
		if offset != 0 {
			return 0, fmt.Errorf("Unaligned word read at address 0x%X", addr)
		}
	}

	return value, nil
}

func (rd *ROM_Device) Write(addr uint32, value uint32, width MEMORY_WIDTH) error {
	// ROM is read-only; ignore writes
	return nil
}

func (rd *ROM_Device) Load(data []uint32) {
	rd.Reset()
	for i := 0; i < len(data) && i < ROM_SIZE; i++ {
		rd.memory[i] = data[i]
		rd.Read(uint32(i), MEMORY_WIDTH_WORD)
	}
	rd.ProgramSize = uint32(len(data))
}

func (rd *ROM_Device) PrintRom() {
	for i := 0; i < int(rd.ProgramSize); i++ {
		fmt.Printf("ROM[%d] = 0x%X\n", i, rd.memory[i])
	}
}

func (rd *ROM_Device) Reset() {
	for i := 0; i < ROM_SIZE; i++ {
		rd.memory[i] = 0xFFFFFFFF
	}
	rd.ProgramSize = 0
}
