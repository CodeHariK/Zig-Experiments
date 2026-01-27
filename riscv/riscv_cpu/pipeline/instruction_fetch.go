package pipeline

import . "riscv/system_interface"

type InstructionFetchParams struct {
	bus *SystemInterface

	shouldStall func() bool
}

func NewInstructionFetchParams(bus *SystemInterface, shouldStall func() bool) *InstructionFetchParams {
	return &InstructionFetchParams{
		bus:         bus,
		shouldStall: shouldStall,
	}
}

type InstructionFetchStage struct {
	pc     Register32
	pcNext Register32

	instruction     Register32
	instructionNext Register32

	bus         *SystemInterface
	shouldStall func() bool
}

func NewInstructionFetchStage(params *InstructionFetchParams) *InstructionFetchStage {
	ifs := &InstructionFetchStage{}
	ifs.pc = Register32{Value: MEMORY_MAP_ROM_START}
	ifs.pcNext = Register32{Value: MEMORY_MAP_ROM_START}
	ifs.instruction = Register32{Value: 0}
	ifs.instructionNext = Register32{Value: 0}
	ifs.bus = params.bus
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
		v, err := ifs.bus.Read(uint64(ifs.pc.Value))
		if err != nil {
			panic(err)
		}
		ifs.instructionNext.Value = uint32(v)
		ifs.pcNext.Value += 4
	}
}

func (ifs *InstructionFetchStage) LatchNext() {
	ifs.instruction.Value = ifs.instructionNext.Value
	ifs.pc.Value = ifs.pcNext.Value
}

func (ifs *InstructionFetchStage) GetInstructionOut() uint32 {
	return ifs.instruction.Value
}
