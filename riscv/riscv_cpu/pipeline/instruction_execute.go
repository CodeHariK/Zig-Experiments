package pipeline

import (
	"fmt"
	. "riscv/system_interface"
)

type ExecuteParams struct {
	shouldStall        func() bool
	getDecodedValuesIn func() DecodedValues
	regFile            *[32]Register32
}

func NewExecuteParams(shouldStall func() bool, getDecodedValuesIn func() DecodedValues, regFile *[32]Register32) *ExecuteParams {
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
	aluResult Register32

	rd                 byte
	rdNext             byte
	isAluOperation     bool
	isAluOperationNext bool

	regFile *[32]Register32

	shouldStall        func() bool
	getDecodedValuesIn func() DecodedValues
}

func NewExecuteStage(params *ExecuteParams) *ExecuteStage {

	ies := &ExecuteStage{}

	ies.aluResult = NewRegister32(0)

	ies.rd = 0
	ies.rdNext = 0
	ies.isAluOperation = false
	ies.isAluOperationNext = false

	ies.regFile = params.regFile

	ies.shouldStall = params.shouldStall
	ies.getDecodedValuesIn = params.getDecodedValuesIn
	return ies
}

func (ies *ExecuteStage) Compute() {
	if !ies.shouldStall() {
		decoded := ies.getDecodedValuesIn()

		// Save destination register for write-back in the latch phase
		ies.rdNext = decoded.Rd

		isRegisterOp := decoded.Opcode>>5 == 1         // Check if opcode indicates register-register operation
		isAlternate := (decoded.Function7 & 0x20) != 0 // Use funct7 bit to distinguish SUB (0100000)

		imm32 := (decoded.Imm_11_0 << 20) >> 20 // Sign-extend 12-bit immediate to 32 bits

		ies.isAluOperationNext = (decoded.Opcode & 0b1011111) == 0b0010011 // R-type or I-type ALU operation

		switch decoded.Function3 {
		case OP_ADD_SUB:
			{
				if isRegisterOp {
					if isAlternate {
						ies.aluResult.SetN(decoded.Rs1 - decoded.Rs2)
						fmt.Printf("Execute: SUB   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResult.GetN())
					} else {
						ies.aluResult.SetN(decoded.Rs1 + decoded.Rs2)
						fmt.Printf("Execute: ADD   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResult.GetN())
					}
				} else {
					ies.aluResult.SetN(decoded.Rs1 + uint32(imm32))
					fmt.Printf("Execute: ADDI  rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1, imm32, ies.aluResult.GetN())
				}
			}
		case OP_SLL:
			{
				if isRegisterOp {
					shiftAmount := decoded.Rs2 & 0x1F
					ies.aluResult.SetN(decoded.Rs1 << shiftAmount)
					fmt.Printf("Execute: SLL   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResult.GetN())
				} else {
					shiftAmount := decoded.Shamt & 0x1F
					ies.aluResult.SetN(decoded.Rs1 << shiftAmount)
					fmt.Printf("Execute: SLLI  rd=%d  rs1=0x%X  shamt=%d -> 0x%X\n", decoded.Rd, decoded.Rs1, shiftAmount, ies.aluResult.GetN())
				}
			}
		case OP_SLT:
			{
				if isRegisterOp {
					if int32(decoded.Rs1) < int32(decoded.Rs2) {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Execute: SLT   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResult.GetN())
				} else {
					if int32(decoded.Rs1) < imm32 {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Execute: SLTI  rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1, imm32, ies.aluResult.GetN())
				}
			}
		case OP_SLTU:
			{
				if isRegisterOp {
					if decoded.Rs1 < decoded.Rs2 {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Execute: SLTU  rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResult.GetN())
				} else {
					if decoded.Rs1 < uint32(imm32) {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Execute: SLTIU rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1, imm32, ies.aluResult.GetN())
				}
			}
		case OP_XOR:
			{
				if isRegisterOp {
					ies.aluResult.SetN(decoded.Rs1 ^ decoded.Rs2)
					fmt.Printf("Execute: XOR   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResult.GetN())
				} else {
					ies.aluResult.SetN(decoded.Rs1 ^ uint32(imm32))
					fmt.Printf("Execute: XORI  rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1, imm32, ies.aluResult.GetN())
				}
			}
		case OP_SRL:
			{
				if isRegisterOp {
					shiftAmount := decoded.Rs2 & 0x1F
					ies.aluResult.SetN(decoded.Rs1 >> shiftAmount)
					fmt.Printf("Execute: SRL   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResult.GetN())
				} else {
					shiftAmount := decoded.Shamt & 0x1F
					ies.aluResult.SetN(decoded.Rs1 >> shiftAmount)
					fmt.Printf("Execute: SRLI  rd=%d  rs1=0x%X  shamt=%d -> 0x%X\n", decoded.Rd, decoded.Rs1, shiftAmount, ies.aluResult.GetN())
				}
			}
		case OP_OR:
			{
				if isRegisterOp {
					ies.aluResult.SetN(decoded.Rs1 | decoded.Rs2)
					fmt.Printf("Execute: OR    rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResult.GetN())
				} else {
					ies.aluResult.SetN(decoded.Rs1 | uint32(imm32))
					fmt.Printf("Execute: ORI   rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1, imm32, ies.aluResult.GetN())
				}
			}
		case OP_AND:
			{
				if isRegisterOp {
					ies.aluResult.SetN(decoded.Rs1 & decoded.Rs2)
					fmt.Printf("Execute: AND   rd=%d  rs1=0x%X  rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResult.GetN())
				} else {
					ies.aluResult.SetN(decoded.Rs1 & uint32(imm32))
					fmt.Printf("Execute: ANDI  rd=%d  rs1=0x%X  imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1, imm32, ies.aluResult.GetN())
				}
			}
		}
	}
}

func (ies *ExecuteStage) LatchNext() {
	ies.aluResult.LatchNext()
	ies.rd = ies.rdNext
	ies.isAluOperation = ies.isAluOperationNext
}

func (ies *ExecuteStage) GetExecutionValuesOut() ExecutedValues {
	return ExecutedValues{
		aluResult:      ies.aluResult.GetN(),
		rd:             ies.rd,
		isAluOperation: ies.isAluOperation,
	}
}
