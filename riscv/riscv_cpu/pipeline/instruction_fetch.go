package pipeline

import (
	"fmt"
	. "riscv/system_interface"
)

type InstructionFetchParams struct {
	bus *SystemInterface

	getBranchAddress      func() uint32
	getBranchAddressValid func() bool

	shouldStall func() bool
}

func NewInstructionFetchParams(
	bus *SystemInterface,
	getBranchAddress func() uint32,
	getBranchAddressValid func() bool,
	shouldStall func() bool) *InstructionFetchParams {
	return &InstructionFetchParams{
		bus:                   bus,
		getBranchAddress:      getBranchAddress,
		getBranchAddressValid: getBranchAddressValid,
		shouldStall:           shouldStall,
	}
}

type InstructionFetchStage struct {
	pc      RUint32
	pcPlus4 RUint32

	getBranchAddress      func() uint32
	getBranchAddressValid func() bool

	instruction RUint32

	bus         *SystemInterface
	shouldStall func() bool
}

func NewInstructionFetchStage(params *InstructionFetchParams) *InstructionFetchStage {
	ifs := &InstructionFetchStage{}

	ifs.pc = NewRUint32(MEMORY_MAP_ROM_START)
	ifs.pcPlus4 = NewRUint32(MEMORY_MAP_ROM_START)
	ifs.instruction = NewRUint32(0)

	ifs.bus = params.bus
	ifs.getBranchAddress = params.getBranchAddress
	ifs.getBranchAddressValid = params.getBranchAddressValid
	ifs.shouldStall = params.shouldStall
	return ifs
}

func (ifs *InstructionFetchStage) readyToSend() bool {
	return true
}

func (ifs *InstructionFetchStage) readyToReceive() bool {
	return true
}

func (ifs *InstructionFetchStage) Compute() {
	if !ifs.shouldStall() {

		if ifs.getBranchAddressValid() {
			ifs.pc.SetN(ifs.getBranchAddress())
			fmt.Println()
		} else {
			ifs.pc.SetN(ifs.pcPlus4.GetN())
		}

		// fmt.Println("@ INSTRUCTION_FETCH")

		ifs.pcPlus4.SetN(ifs.pc.GetN() + 4)

		ins, err := ifs.bus.Read(ifs.pc.GetN(), MEMORY_WIDTH_WORD)
		if err != nil {
			panic(err)
		}

		fmt.Printf("PC=0x%08X  INS=0x%08X ", ifs.pc.GetN(), ins)

		ifs.instruction.SetN(ins)
	}
}

func (ifs *InstructionFetchStage) LatchNext() {
	ifs.instruction.LatchNext()
	ifs.pc.LatchNext()
	ifs.pcPlus4.LatchNext()
}

type FetchValues struct {
	Instruction uint32
	pc          uint32
	pcPlus4     uint32
}

func (ifs *InstructionFetchStage) GetFetchValuesOut() FetchValues {
	return FetchValues{
		Instruction: ifs.instruction.GetN(),
		pc:          ifs.pc.GetN(),
		pcPlus4:     ifs.pcPlus4.GetN(),
	}
}
