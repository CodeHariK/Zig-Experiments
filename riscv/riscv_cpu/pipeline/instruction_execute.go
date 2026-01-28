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
	aluResult     Register32
	aluResultNext Register32

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

	ies.aluResult = Register32{Value: 0}
	ies.aluResultNext = Register32{Value: 0}

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
						ies.aluResultNext.Value = decoded.Rs1 - decoded.Rs2 // SUB
						fmt.Printf("Execute: SUB rd=%d rs1=0x%X rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResultNext.Value)
					} else {
						ies.aluResultNext.Value = decoded.Rs1 + decoded.Rs2 // ADD
						fmt.Printf("Execute: ADD rd=%d rs1=0x%X rs2=0x%X -> 0x%X\n", decoded.Rd, decoded.Rs1, decoded.Rs2, ies.aluResultNext.Value)
					}
				} else {
					ies.aluResultNext.Value = decoded.Rs1 + uint32(imm32) // ADDI
					fmt.Printf("Execute: ADDI rd=%d rs1=0x%X imm=%d -> 0x%X\n", decoded.Rd, decoded.Rs1, imm32, ies.aluResultNext.Value)
				}
			}
		}
	}
}

func (ies *ExecuteStage) LatchNext() {
	ies.aluResult = ies.aluResultNext
	ies.rd = ies.rdNext
	ies.isAluOperation = ies.isAluOperationNext
}

func (ies *ExecuteStage) GetExecutionValuesOut() ExecutedValues {
	return ExecutedValues{
		aluResult:      ies.aluResult.Value,
		rd:             ies.rd,
		isAluOperation: ies.isAluOperation,
	}
}
