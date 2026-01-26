package systeminterface

import "fmt"

const ROM_SIZE = 1024 * 1024 / 4 // 1 MB = 1024 * 1024 bytes = 256K int32
const ROM_MASK = ROM_SIZE - 1

type ROM_Device struct {
	memory      [ROM_SIZE]uint32
	ProgramSize uint64
}

func (rd *ROM_Device) Read(addr uint64) (uint64, error) {
	return uint64(rd.memory[addr&ROM_MASK]), nil
}

func (rd *ROM_Device) Write(addr uint64, value uint64) error {
	// ROM is read-only; ignore writes
	return nil
}

func (rd *ROM_Device) Load(data []uint32) {
	for i := 0; i < len(data) && i < ROM_SIZE; i++ {
		if i >= len(data) {
			rd.memory[i] = 0xFFFFFFFF
		} else {
			rd.memory[i] = data[i]
			rd.Read(uint64(i))
		}
	}
	rd.ProgramSize = uint64(len(data))
}

func (rd *ROM_Device) PrintRom() {
	for i := 0; i < int(rd.ProgramSize); i++ {
		fmt.Printf("ROM[%d] = 0x%X\n", i, rd.memory[i])
	}
}
