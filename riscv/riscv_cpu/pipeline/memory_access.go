package pipeline

import (
	"fmt"
	. "riscv/system_interface"
)

type ExecutedValues struct {
	aluResult        uint32
	rd               byte
	rs1V             uint32
	rs2V             uint32
	isAluOperation   bool
	isStoreOperation bool
	imm32            int32
	func3            byte
}

type MemoryAccessParams struct {
	bus SystemInterface

	shouldStall          func() bool
	getExecutionValuesIn func() ExecutedValues
}

func NewMemoryAccessParams(bus SystemInterface, shouldStall func() bool, getExecutionValuesIn func() ExecutedValues) *MemoryAccessParams {
	return &MemoryAccessParams{
		shouldStall:          shouldStall,
		getExecutionValuesIn: getExecutionValuesIn,
		bus:                  bus,
	}
}

const (
	LOAD_FUNC3_LB  = 0b000
	LOAD_FUNC3_LH  = 0b001
	LOAD_FUNC3_LW  = 0b010
	LOAD_FUNC3_LBU = 0b100
	LOAD_FUNC3_LHU = 0b101

	STORE_FUNC3_SB = 0b000
	STORE_FUNC3_SH = 0b001
	STORE_FUNC3_SW = 0b010
)

type MemoryAccessStage struct {
	shouldStall          func() bool
	getExecutionValuesIn func() ExecutedValues

	bus SystemInterface

	aluResult      RUint32
	rd             RByte
	isAluOperation RBool
}

func NewMemoryAccessStage(params *MemoryAccessParams) *MemoryAccessStage {

	ma := &MemoryAccessStage{}

	ma.shouldStall = params.shouldStall
	ma.getExecutionValuesIn = params.getExecutionValuesIn
	ma.bus = params.bus

	ma.aluResult = NewRUint32(0)
	ma.rd = NewRByte(0)
	ma.isAluOperation = NewRBool(false)

	return ma
}

func (ma *MemoryAccessStage) Compute() {
	if !ma.shouldStall() {
		ev := ma.getExecutionValuesIn()

		ma.aluResult.SetN(ev.aluResult)
		ma.rd.SetN(ev.rd)
		ma.isAluOperation.SetN(ev.isAluOperation)

		if ev.isStoreOperation {

			addr := uint32(int32(ev.rs1V) + ev.imm32)

			switch ev.func3 {
			case STORE_FUNC3_SB:
				// Store Byte
				err := ma.bus.Write(addr, ev.rs2V&0xFF, MEMORY_WIDTH_BYTE)
				fmt.Printf("STORE BYTE: SB Addr=0x%X, Value=0x%X, %v \n", addr, ev.rs2V&0xFF, err)
			case STORE_FUNC3_SH:
				// Store Halfword
				err := ma.bus.Write(addr, ev.rs2V&0xFFFF, MEMORY_WIDTH_HALF)
				fmt.Printf("STORE HALFWORD: SH Addr=0x%X, Value=0x%X, %v \n", addr, ev.rs2V&0xFFFF, err)
			case STORE_FUNC3_SW:
				// Store Word
				err := ma.bus.Write(addr, ev.rs2V, MEMORY_WIDTH_WORD)
				fmt.Printf("STORE WORD: SW Addr=0x%X, Value=0x%X, %v \n", addr, ev.rs2V, err)
			default:
				panic(fmt.Sprintf("Unsupported store func3: 0b%03b", ev.func3))
			}

		}
	}
}

func (ma *MemoryAccessStage) LatchNext() {
	ma.aluResult.LatchNext()
	ma.rd.LatchNext()
	ma.isAluOperation.LatchNext()
}

func (ma *MemoryAccessStage) GetMemoryAccessValuesOut() ExecutedValues {
	return ExecutedValues{
		aluResult:      ma.aluResult.GetN(),
		rd:             ma.rd.GetN(),
		isAluOperation: ma.isAluOperation.GetN(),
	}
}
