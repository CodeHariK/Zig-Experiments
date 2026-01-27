package pipeline

import . "riscv/system_interface"

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

	rd     byte
	rdNext byte

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

		switch decoded.Function3 {
		case OP_ADD_SUB:
			{
				if isRegisterOp {
					if isAlternate {
						ies.aluResultNext.Value = decoded.Rs1 - decoded.Rs2 // SUB
					} else {
						ies.aluResultNext.Value = decoded.Rs1 + decoded.Rs2 // ADD
					}
				} else {
					ies.aluResultNext.Value = decoded.Rs1 + uint32(imm32) // ADDI
				}
			}
		}
	}
}

func (ies *ExecuteStage) LatchNext() {
	ies.aluResult = ies.aluResultNext
	ies.rd = ies.rdNext
	// Write-back to register file (x0 is hardwired zero)
	if ies.regFile != nil && ies.rd != 0 {
		ies.regFile[ies.rd].Value = ies.aluResult.Value
	}
}

func (ies *ExecuteStage) GetALUResultOut() uint32 {
	return ies.aluResult.Value
}
