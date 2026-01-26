package systeminterface

const RAM_SIZE = 1024 * 1024 * 4 / 4 // 4 MB = 1024 * 1024 * 4 bytes = 1M int32
const RAM_MASK = RAM_SIZE - 1

type RAM_Device struct {
	memory [RAM_SIZE]uint32
}

func (rd *RAM_Device) Read(addr uint64) (uint64, error) {
	return uint64(rd.memory[addr&RAM_MASK]), nil
}

func (rd *RAM_Device) Write(addr uint64, value uint64) error {
	rd.memory[addr&RAM_MASK] = uint32(value)
	return nil
}
