package pipeline

import (
	"fmt"
	. "riscv/system_interface"
)

type ExecutedValues struct {
	writeBackValue   uint32
	rd               byte
	rs1V             uint32
	rs2V             uint32
	isAluOperation   bool
	isStoreOperation bool
	isLoadOperation  bool
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

	writeBackValue  RUint32
	rd              RByte
	isAluOperation  RBool
	isLoadOperation RBool
}

func NewMemoryAccessStage(params *MemoryAccessParams) *MemoryAccessStage {

	ma := &MemoryAccessStage{}

	ma.shouldStall = params.shouldStall
	ma.getExecutionValuesIn = params.getExecutionValuesIn
	ma.bus = params.bus

	ma.writeBackValue = NewRUint32(0)
	ma.rd = NewRByte(0)
	ma.isAluOperation = NewRBool(false)
	ma.isLoadOperation = NewRBool(false)

	return ma
}

func (ma *MemoryAccessStage) Compute() {
	if !ma.shouldStall() {
		ev := ma.getExecutionValuesIn()

		ma.writeBackValue.SetN(ev.writeBackValue)
		ma.rd.SetN(ev.rd)
		ma.isAluOperation.SetN(ev.isAluOperation)
		ma.isLoadOperation.SetN(ev.isLoadOperation)

		addr := uint32(int32(ev.rs1V) + ev.imm32)

		if ev.isStoreOperation {

			switch ev.func3 {
			case STORE_FUNC3_SB:
				// Store Byte
				err := ma.bus.Write(addr, ev.rs2V&0xFF, MEMORY_WIDTH_BYTE)
				fmt.Printf("STORE  : SB    Addr=0x%X, Value=0x%X, %v \n", addr, ev.rs2V&0xFF, err)
			case STORE_FUNC3_SH:
				// Store Halfword
				err := ma.bus.Write(addr, ev.rs2V&0xFFFF, MEMORY_WIDTH_HALF)
				fmt.Printf("STORE  : SH    Addr=0x%X, Value=0x%X, %v \n", addr, ev.rs2V&0xFFFF, err)
			case STORE_FUNC3_SW:
				// Store Word
				err := ma.bus.Write(addr, ev.rs2V, MEMORY_WIDTH_WORD)
				fmt.Printf("STORE  : SW    Addr=0x%X, Value=0x%X, %v \n", addr, ev.rs2V, err)
			default:
				panic(fmt.Sprintf("Unsupported store func3: 0b%03b", ev.func3))
			}

		} else if ev.isLoadOperation {
			shouldSignExtend := (ev.func3 & 0b100) == 0

			var value uint32

			switch ev.func3 & 0b011 {
			case LOAD_FUNC3_LB:
				// Load Byte (sign-extended)
				memvalue, err := ma.bus.Read(addr, MEMORY_WIDTH_BYTE)
				if err != nil {
					fmt.Printf("LOAD   : LB/U  ERROR: %s", err.Error())
					break
				}
				if shouldSignExtend {
					value = uint32(int32(int8(memvalue & 0xFF)))
					fmt.Printf("LOAD   : LB    Addr=0x%X, Value=0x%X -> R%d", addr, value, ev.rd)
				} else {
					value = memvalue & 0xFF
					fmt.Printf("LOAD   : LBU   Addr=0x%X, Value=0x%X -> R%d", addr, value, ev.rd)
				}
			case LOAD_FUNC3_LH:
				// Load Halfword (sign-extended)
				memvalue, err := ma.bus.Read(addr, MEMORY_WIDTH_HALF)
				if err != nil {
					fmt.Printf("LOAD   : LH/U  ERROR: %s", err.Error())
					break
				}
				if shouldSignExtend {
					value = uint32(int32(int16(memvalue & 0xFFFF)))
					fmt.Printf("LOAD   : LH    Addr=0x%X, Value=0x%X -> R%d", addr, value, ev.rd)
				} else {
					value = memvalue & 0xFFFF
					fmt.Printf("LOAD   : LHU   Addr=0x%X, Value=0x%X -> R%d", addr, value, ev.rd)
				}
			case LOAD_FUNC3_LW:
				// Load Word
				memvalue, err := ma.bus.Read(addr, MEMORY_WIDTH_WORD)
				if err != nil {
					fmt.Printf("LOAD   : LW    ERROR: %s", err.Error())
					break
				}
				value = memvalue
				fmt.Printf("LOAD   : LW    Addr=0x%X, Value=0x%X -> R%d", addr, value, ev.rd)
			default:
				panic(fmt.Sprintf("Unsupported load func3: 0b%03b", ev.func3))
			}

			ma.writeBackValue.SetN(value)
		}
	}
}

func (ma *MemoryAccessStage) LatchNext() {
	ma.writeBackValue.LatchNext()
	ma.rd.LatchNext()
	ma.isAluOperation.LatchNext()
	ma.isLoadOperation.LatchNext()
}

func (ma *MemoryAccessStage) GetMemoryAccessValuesOut() ExecutedValues {
	return ExecutedValues{
		writeBackValue:  ma.writeBackValue.GetN(),
		rd:              ma.rd.GetN(),
		isAluOperation:  ma.isAluOperation.GetN(),
		isLoadOperation: ma.isLoadOperation.GetN(),
	}
}
