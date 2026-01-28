package systeminterface

import "fmt"

const RAM_SIZE = 1024 * 1024 * 4 / 4 // 4 MB = 1024 * 1024 * 4 bytes = 1M int32
const RAM_MASK = RAM_SIZE - 1

type RAM_Device struct {
	memory [RAM_SIZE]uint32
}

func (rd *RAM_Device) Read(addr uint32, width MEMORY_WIDTH) (uint32, error) {

	offset := addr & 0b11
	wordAddr := addr >> 2
	value := rd.memory[wordAddr&RAM_MASK]

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
		switch offset {
		case 0:
			value = (value >> 16) & 0xFFFF
		case 2:
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

func (rd *RAM_Device) Write(addr uint32, value uint32, width MEMORY_WIDTH) error {

	offset := addr & 0b11
	maskedAddr := (addr >> 2) & RAM_MASK
	currentValue := rd.memory[maskedAddr]

	switch width {
	case MEMORY_WIDTH_BYTE:
		switch offset {
		case 0:
			rd.memory[maskedAddr] = ((currentValue & 0x00FFFFFF) | ((value & 0xFF) << 24))
		case 1:
			rd.memory[maskedAddr] = ((currentValue & 0xFF00FFFF) | ((value & 0xFF) << 16))
		case 2:
			rd.memory[maskedAddr] = ((currentValue & 0xFFFF00FF) | ((value & 0xFF) << 8))
		case 3:
			rd.memory[maskedAddr] = ((currentValue & 0xFFFFFF00) | (value & 0xFF))
		}
	case MEMORY_WIDTH_HALF:
		{
			switch offset {
			case 0:
				rd.memory[maskedAddr] = ((currentValue & 0x0000FFFF) | ((value & 0xFFFF) << 16))
			case 2:
				rd.memory[maskedAddr] = ((currentValue & 0xFFFF0000) | (value & 0xFFFF))
			default:
				return fmt.Errorf("Unaligned halfword write at address 0x%X", addr)
			}
		}
	case MEMORY_WIDTH_WORD:
		{
			if offset != 0 {
				return fmt.Errorf("Unaligned word write at address 0x%X", addr)
			}
			rd.memory[maskedAddr] = (value & 0xFFFFFFFF)
		}
	}

	return nil
}
