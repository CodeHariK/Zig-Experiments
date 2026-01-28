package pipeline

import (
	"fmt"
	. "riscv/system_interface"
)

type ExecuteParams struct {
	shouldStall        func() bool
	getDecodedValuesIn func() DecodedValues
	regFile            *[32]RUint32
}

func NewExecuteParams(shouldStall func() bool, getDecodedValuesIn func() DecodedValues, regFile *[32]RUint32) *ExecuteParams {
	return &ExecuteParams{
		shouldStall:        shouldStall,
		getDecodedValuesIn: getDecodedValuesIn,
		regFile:            regFile,
	}
}

const (
	OP_ADD_SUB = 0b000
	OP_SLL     = 0b001
	OP_SLT     = 0b010
	OP_SLTU    = 0b011
	OP_XOR     = 0b100
	OP_SRL     = 0b101
	OP_OR      = 0b110
	OP_AND     = 0b111
)

type ExecuteStage struct {
	aluResult RUint32

	rd               RByte
	rs1V             RUint32
	rs2V             RUint32
	isAluOperation   RBool
	isStoreOperation RBool
	imm32            RInt32
	func3            RByte

	regFile *[32]RUint32

	shouldStall        func() bool
	getDecodedValuesIn func() DecodedValues
}

func NewExecuteStage(params *ExecuteParams) *ExecuteStage {

	ies := &ExecuteStage{}

	ies.aluResult = NewRUint32(0)

	ies.rd = NewRByte(0)
	ies.rs1V = NewRUint32(0)
	ies.rs2V = NewRUint32(0)
	ies.isAluOperation = NewRBool(false)
	ies.isStoreOperation = NewRBool(false)
	ies.imm32 = NewRInt32(0)
	ies.func3 = NewRByte(0)

	ies.regFile = params.regFile

	ies.shouldStall = params.shouldStall
	ies.getDecodedValuesIn = params.getDecodedValuesIn
	return ies
}

func (ies *ExecuteStage) Compute() {
	if !ies.shouldStall() {
		decoded := ies.getDecodedValuesIn()

		ies.isAluOperation.SetN(decoded.IsAluOperation)
		ies.isStoreOperation.SetN(decoded.IsStoreOperation)
		ies.imm32.SetN(decoded.Imm32)
		ies.func3.SetN(decoded.Func3)

		imm32 := decoded.Imm32

		// Save destination register for write-back in the latch phase
		ies.rd.SetN(decoded.Rd)
		ies.rs1V.SetN(decoded.Rs1V)
		ies.rs2V.SetN(decoded.Rs2V)

		isRegisterOp := decoded.Opcode>>5 == 1     // Check if opcode indicates register-register operation
		isAlternate := (decoded.Func7 & 0x20) != 0 // Use funct7 bit to distinguish SUB (0100000)

		if decoded.IsAluOperation == false {
			// Not an ALU operation; nothing to do here
			return
		}

		// Perform ALU operation
		switch decoded.Func3 {
		case OP_ADD_SUB:
			{
				if isRegisterOp {
					if isAlternate {
						ies.aluResult.SetN(decoded.Rs1V - decoded.Rs2V)
						fmt.Printf("Execute: SUB   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1V, decoded.Rs2V, ies.aluResult.GetN())
					} else {
						ies.aluResult.SetN(decoded.Rs1V + decoded.Rs2V)
						fmt.Printf("Execute: ADD   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1V, decoded.Rs2V, ies.aluResult.GetN())
					}
				} else {
					ies.aluResult.SetN(decoded.Rs1V + uint32(imm32))
					fmt.Printf("Execute: ADDI  rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_SLL:
			{
				if isRegisterOp {
					shiftAmount := decoded.Rs2V & 0x1F
					ies.aluResult.SetN(decoded.Rs1V << shiftAmount)
					fmt.Printf("Execute: SLL   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1V, decoded.Rs2V, ies.aluResult.GetN())
				} else {
					shiftAmount := decoded.Shamt & 0x1F
					ies.aluResult.SetN(decoded.Rs1V << shiftAmount)
					fmt.Printf("Execute: SLLI  rd=%d  rs1=0x%X  shamt=%d -> 0x%X\n", decoded.Rd, decoded.Rs1V, shiftAmount, ies.aluResult.GetN())
				}
			}
		case OP_SLT:
			{
				if isRegisterOp {
					if int32(decoded.Rs1V) < int32(decoded.Rs2V) {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Execute: SLT   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1V, decoded.Rs2V, ies.aluResult.GetN())
				} else {
					if int32(decoded.Rs1V) < imm32 {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Execute: SLTI  rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_SLTU:
			{
				if isRegisterOp {
					if decoded.Rs1V < decoded.Rs2V {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Execute: SLTU  rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1V, decoded.Rs2V, ies.aluResult.GetN())
				} else {
					if decoded.Rs1V < uint32(imm32) {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Execute: SLTIU rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_XOR:
			{
				if isRegisterOp {
					ies.aluResult.SetN(decoded.Rs1V ^ decoded.Rs2V)
					fmt.Printf("Execute: XOR   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1V, decoded.Rs2V, ies.aluResult.GetN())
				} else {
					ies.aluResult.SetN(decoded.Rs1V ^ uint32(imm32))
					fmt.Printf("Execute: XORI  rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_SRL:
			{
				if isRegisterOp {
					shiftAmount := decoded.Rs2V & 0x1F
					ies.aluResult.SetN(decoded.Rs1V >> shiftAmount)
					fmt.Printf("Execute: SRL   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1V, decoded.Rs2V, ies.aluResult.GetN())
				} else {
					shiftAmount := decoded.Shamt & 0x1F
					ies.aluResult.SetN(decoded.Rs1V >> shiftAmount)
					fmt.Printf("Execute: SRLI  rd=%d  rs1=0x%X  shamt=%d -> 0x%X\n", decoded.Rd, decoded.Rs1V, shiftAmount, ies.aluResult.GetN())
				}
			}
		case OP_OR:
			{
				if isRegisterOp {
					ies.aluResult.SetN(decoded.Rs1V | decoded.Rs2V)
					fmt.Printf("Execute: OR    rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1V, decoded.Rs2V, ies.aluResult.GetN())
				} else {
					ies.aluResult.SetN(decoded.Rs1V | uint32(imm32))
					fmt.Printf("Execute: ORI   rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_AND:
			{
				if isRegisterOp {
					ies.aluResult.SetN(decoded.Rs1V & decoded.Rs2V)
					fmt.Printf("Execute: AND   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1V, decoded.Rs2V, ies.aluResult.GetN())
				} else {
					ies.aluResult.SetN(decoded.Rs1V & uint32(imm32))
					fmt.Printf("Execute: ANDI  rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1V, imm32, ies.aluResult.GetN())
				}
			}
		}
	}
}

func (ies *ExecuteStage) LatchNext() {
	ies.aluResult.LatchNext()
	ies.rd.LatchNext()
	ies.rs1V.LatchNext()
	ies.rs2V.LatchNext()
	ies.isAluOperation.LatchNext()
	ies.isStoreOperation.LatchNext()
	ies.imm32.LatchNext()
	ies.func3.LatchNext()
}

func (ies *ExecuteStage) GetExecutionValuesOut() ExecutedValues {
	return ExecutedValues{
		aluResult:        ies.aluResult.GetN(),
		rd:               ies.rd.GetN(),
		rs1V:             ies.rs1V.GetN(),
		rs2V:             ies.rs2V.GetN(),
		isAluOperation:   ies.isAluOperation.GetN(),
		isStoreOperation: ies.isStoreOperation.GetN(),
		imm32:            ies.imm32.GetN(),
		func3:            ies.func3.GetN(),
	}
}
