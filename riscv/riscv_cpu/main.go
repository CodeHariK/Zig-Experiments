package main

import (
	. "riscv/pipeline"
	. "riscv/system_interface"
)

const (
	INSTRUCTION_FETCH = byte(iota)
	DECODE
	EXECUTE
	MEMORY_ACCESS
	WRITE_BACK
)

type RVI32System struct {
	state byte

	ram     RAM_Device
	rom     ROM_Device
	regFile [32]RUint32

	bus SystemInterface

	IF *InstructionFetchStage
	DE *DecodeStage
	EX *ExecuteStage
	MA *MemoryAccessStage
	WB *WriteBackStage
}

func NewRVI32System() *RVI32System {
	sys := &RVI32System{}

	sys.state = INSTRUCTION_FETCH

	sys.ram = RAM_Device{}
	sys.rom = ROM_Device{}

	// sys.regFile = [32]Register32{}

	sys.bus = *NewSystemInterface(&sys.rom, &sys.ram)

	ifsParams := NewInstructionFetchParams(
		&sys.bus,
		func() bool {
			return sys.state != INSTRUCTION_FETCH
		},
	)
	sys.IF = NewInstructionFetchStage(ifsParams)

	decodeParams := NewDecodeParams(
		&sys.regFile,
		func() bool {
			return sys.state != DECODE
		},
		sys.IF.GetInstructionOut,
	)
	sys.DE = NewDecodeStage(decodeParams)

	executeParams := NewExecuteParams(
		func() bool {
			return sys.state != EXECUTE
		},
		sys.DE.GetDecodedValues,
		&sys.regFile,
	)
	sys.EX = NewExecuteStage(executeParams)

	memoryAccessParams := NewMemoryAccessParams(
		func() bool {
			return sys.state != MEMORY_ACCESS
		},
		sys.EX.GetExecutionValuesOut,
	)
	sys.MA = NewMemoryAccessStage(memoryAccessParams)

	writeBackParams := NewWriteBackParams(
		&sys.regFile,
		func() bool {
			return sys.state != WRITE_BACK
		},
		sys.MA.GetMemoryAccessValuesOut,
	)
	sys.WB = NewWriteBackStage(writeBackParams)

	return sys
}

func (sys *RVI32System) Compute() {
	sys.IF.Compute()
	sys.DE.Compute()
	sys.EX.Compute()
	sys.MA.Compute()
	sys.WB.Compute()
}

func (sys *RVI32System) LatchNext() {
	sys.IF.LatchNext()
	sys.DE.LatchNext()
	sys.EX.LatchNext()
	sys.MA.LatchNext()
	sys.WB.LatchNext()

	for i := range sys.regFile {
		sys.regFile[i].LatchNext()
	}
}

func (sys *RVI32System) Cycle() {
	sys.Compute()
	sys.LatchNext()

	switch sys.state {
	case INSTRUCTION_FETCH:
		sys.state = DECODE
	case DECODE:
		sys.state = EXECUTE
	case EXECUTE:
		sys.state = MEMORY_ACCESS
	case MEMORY_ACCESS:
		sys.state = WRITE_BACK
	case WRITE_BACK:
		sys.state = INSTRUCTION_FETCH
	}
}

func main() {
	println("Hello, World!")
}
