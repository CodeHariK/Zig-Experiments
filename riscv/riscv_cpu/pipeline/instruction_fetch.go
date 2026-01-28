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
	pc Register32

	instruction Register32

	bus         *SystemInterface
	shouldStall func() bool
}

func NewInstructionFetchStage(params *InstructionFetchParams) *InstructionFetchStage {
	ifs := &InstructionFetchStage{}
	ifs.pc = NewRegister32(MEMORY_MAP_ROM_START)
	ifs.instruction = NewRegister32(0)
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
		v, err := ifs.bus.Read(uint64(ifs.pc.GetN()))
		if err != nil {
			panic(err)
		}
		ifs.instruction.SetN(uint32(v))
		ifs.pc.SetN(ifs.pc.GetN() + 4)
	}
}

func (ifs *InstructionFetchStage) LatchNext() {
	ifs.instruction.LatchNext()
	ifs.pc.LatchNext()
}

func (ifs *InstructionFetchStage) GetInstructionOut() uint32 {
	return ifs.instruction.GetN()
}
