package riscv

import (
	"fmt"
	. "riscv/pipeline"
	. "riscv/system_interface"
)

const (
	INSTRUCTION_FETCH = byte(iota)
	DECODE
	EXECUTE
	MEMORY_ACCESS
	WRITE_BACK

	TERMINATE
)

type RVI32System struct {
	State byte

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

	sys.State = INSTRUCTION_FETCH

	sys.ram = RAM_Device{}
	sys.rom = ROM_Device{}

	// sys.regFile = [32]Register32{}

	sys.bus = *NewSystemInterface(&sys.rom, &sys.ram)

	ifsParams := NewInstructionFetchParams(
		&sys.bus,
		func() uint32 {
			return uint32(sys.EX.GetExecutionValuesOut().BranchAddress)
		},
		func() bool {
			return sys.EX.GetExecutionValuesOut().BranchValid
		},
		func() bool {
			return sys.State != INSTRUCTION_FETCH
		},
	)
	sys.IF = NewInstructionFetchStage(ifsParams)

	decodeParams := NewDecodeParams(
		&sys.regFile,
		func() bool {
			return sys.State != DECODE
		},
		sys.IF.GetFetchValuesOut,
	)
	sys.DE = NewDecodeStage(decodeParams)

	executeParams := NewExecuteParams(
		func() bool {
			return sys.State != EXECUTE
		},
		sys.DE.GetDecodedValuesOut,
		&sys.regFile,
	)
	sys.EX = NewExecuteStage(executeParams)

	memoryAccessParams := NewMemoryAccessParams(
		sys.bus,
		func() bool {
			return sys.State != MEMORY_ACCESS
		},
		sys.EX.GetExecutionValuesOut,
	)
	sys.MA = NewMemoryAccessStage(memoryAccessParams)

	writeBackParams := NewWriteBackParams(
		&sys.regFile,
		func() bool {
			return sys.State != WRITE_BACK
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

	switch sys.State {
	case INSTRUCTION_FETCH:
		sys.State = DECODE
	case DECODE:
		sys.State = EXECUTE
	case EXECUTE:
		sys.State = MEMORY_ACCESS
	case MEMORY_ACCESS:
		sys.State = WRITE_BACK
	case WRITE_BACK:
		sys.State = INSTRUCTION_FETCH
	}

	if sys.IF.GetFetchValuesOut().Instruction == 0 {
		sys.State = TERMINATE
		fmt.Print("\n---- TERMINATE ----\n")
		return
	}
}
