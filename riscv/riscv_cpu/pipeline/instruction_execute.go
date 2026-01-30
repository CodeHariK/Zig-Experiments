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

	rd   RByte
	rs1V RUint32
	rs2V RUint32

	isAluOp   RBool
	isStoreOp RBool
	isLoadOp  RBool
	isLUIOp   RBool
	isJUMPOp  RBool

	imm32 RInt32
	func3 RByte

	pcPlus4 RUint32

	regFile *[32]RUint32

	shouldStall        func() bool
	getDecodedValuesIn func() DecodedValues
}

func NewExecuteStage(params *ExecuteParams) *ExecuteStage {

	ies := &ExecuteStage{}

	ies.regFile = params.regFile

	ies.shouldStall = params.shouldStall
	ies.getDecodedValuesIn = params.getDecodedValuesIn
	return ies
}

func (ies *ExecuteStage) Compute() {
	if !ies.shouldStall() {
		// fmt.Println("@ EXECUTE")

		decoded := ies.getDecodedValuesIn()

		ies.isAluOp.SetN(decoded.isAluOp)
		ies.isStoreOp.SetN(decoded.isStoreOp)
		ies.isLoadOp.SetN(decoded.isLoadOp)
		ies.isLUIOp.SetN(decoded.isLUIOp)
		ies.isJUMPOp.SetN(decoded.IsJUMPOp)

		ies.pcPlus4.SetN(decoded.pcPlus4)

		ies.imm32.SetN(decoded.imm)
		ies.func3.SetN(decoded.func3)

		imm32 := decoded.imm

		// Save destination register for write-back in the latch phase
		ies.rd.SetN(decoded.rd)
		ies.rs1V.SetN(decoded.rs1V)
		ies.rs2V.SetN(decoded.rs2V)

		isRegisterOp := decoded.opcode>>5 == 1     // Check if opcode indicates register-register operation
		isAlternate := (decoded.func7 & 0x20) != 0 // Use funct7 bit to distinguish SUB (0100000)

		if decoded.isAluOp == false {
			// Not an ALU operation; nothing to do here
			return
		}

		// Perform ALU operation
		switch decoded.func3 {
		case OP_ADD_SUB:
			{
				if isRegisterOp {
					if isAlternate {
						ies.aluResult.SetN(decoded.rs1V - decoded.rs2V)
						fmt.Printf("Exec   : SUB   rd=%2d  rs1=0x%08X  rs2=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, decoded.rs2V, ies.aluResult.GetN())
					} else {
						ies.aluResult.SetN(decoded.rs1V + decoded.rs2V)
						fmt.Printf("Exec   : ADD   rd=%2d  rs1=0x%08X  rs2=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, decoded.rs2V, ies.aluResult.GetN())
					}
				} else {
					ies.aluResult.SetN(decoded.rs1V + uint32(imm32))
					fmt.Printf("Exec   : ADDI  rd=%2d  rs1=0x%08X  imm=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_SLL:
			{
				if isRegisterOp {
					shiftAmount := decoded.rs2V & 0x1F
					ies.aluResult.SetN(decoded.rs1V << shiftAmount)
					fmt.Printf("Exec   : SLL   rd=%2d  rs1=0x%08X  rs2=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, decoded.rs2V, ies.aluResult.GetN())
				} else {
					shiftAmount := decoded.shamt & 0x1F
					ies.aluResult.SetN(decoded.rs1V << shiftAmount)
					fmt.Printf("Exec   : SLLI  rd=%2d  rs1=0x%08X  sha=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, shiftAmount, ies.aluResult.GetN())
				}
			}
		case OP_SLT:
			{
				if isRegisterOp {
					if int32(decoded.rs1V) < int32(decoded.rs2V) {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Exec   : SLT   rd=%2d  rs1=0x%08X  rs2=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, decoded.rs2V, ies.aluResult.GetN())
				} else {
					if int32(decoded.rs1V) < imm32 {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Exec   : SLTI  rd=%2d  rs1=0x%08X  imm=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_SLTU:
			{
				if isRegisterOp {
					if decoded.rs1V < decoded.rs2V {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Exec   : SLTU  rd=%2d  rs1=0x%08X  rs2=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, decoded.rs2V, ies.aluResult.GetN())
				} else {
					if decoded.rs1V < uint32(imm32) {
						ies.aluResult.SetN(1)
					} else {
						ies.aluResult.SetN(0)
					}
					fmt.Printf("Exec   : SLTIU rd=%2d  rs1=0x%08X  imm=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_XOR:
			{
				if isRegisterOp {
					ies.aluResult.SetN(decoded.rs1V ^ decoded.rs2V)
					fmt.Printf("Exec   : XOR   rd=%2d  rs1=0x%08X  rs2=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, decoded.rs2V, ies.aluResult.GetN())
				} else {
					ies.aluResult.SetN(decoded.rs1V ^ uint32(imm32))
					fmt.Printf("Exec   : XORI  rd=%2d  rs1=0x%08X  imm=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_SRL:
			{
				if isRegisterOp {
					shiftAmount := decoded.rs2V & 0x1F
					ies.aluResult.SetN(decoded.rs1V >> shiftAmount)
					fmt.Printf("Exec   : SRL   rd=%2d  rs1=0x%08X  rs2=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, decoded.rs2V, ies.aluResult.GetN())
				} else {
					shiftAmount := decoded.shamt & 0x1F
					ies.aluResult.SetN(decoded.rs1V >> shiftAmount)
					fmt.Printf("Exec   : SRLI  rd=%2d  rs1=0x%08X  sha=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, shiftAmount, ies.aluResult.GetN())
				}
			}
		case OP_OR:
			{
				if isRegisterOp {
					ies.aluResult.SetN(decoded.rs1V | decoded.rs2V)
					fmt.Printf("Exec   : OR    rd=%2d  rs1=0x%08X  rs2=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, decoded.rs2V, ies.aluResult.GetN())
				} else {
					ies.aluResult.SetN(decoded.rs1V | uint32(imm32))
					fmt.Printf("Exec   : ORI   rd=%2d  rs1=0x%08X  imm=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, imm32, ies.aluResult.GetN())
				}
			}
		case OP_AND:
			{
				if isRegisterOp {
					ies.aluResult.SetN(decoded.rs1V & decoded.rs2V)
					fmt.Printf("Exec   : AND   rd=%2d  rs1=0x%08X  rs2=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, decoded.rs2V, ies.aluResult.GetN())
				} else {
					ies.aluResult.SetN(decoded.rs1V & uint32(imm32))
					fmt.Printf("Exec   : ANDI  rd=%2d  rs1=0x%08X  imm=0x%08X -> 0x%08X", decoded.rd, decoded.rs1V, imm32, ies.aluResult.GetN())
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

	ies.isAluOp.LatchNext()
	ies.isStoreOp.LatchNext()
	ies.isLoadOp.LatchNext()
	ies.isLUIOp.LatchNext()
	ies.isJUMPOp.LatchNext()

	ies.pcPlus4.LatchNext()

	ies.imm32.LatchNext()
	ies.func3.LatchNext()
}

func (ies *ExecuteStage) GetExecutionValuesOut() ExecutedValues {
	return ExecutedValues{
		isAluOp:   ies.isAluOp.GetN(),
		isStoreOp: ies.isStoreOp.GetN(),
		isLoadOp:  ies.isLoadOp.GetN(),
		isLUIOp:   ies.isLUIOp.GetN(),
		isJUMPOp:  ies.isJUMPOp.GetN(),

		writeBackValue: ies.aluResult.GetN(),
		rd:             ies.rd.GetN(),
		rs1V:           ies.rs1V.GetN(),
		rs2V:           ies.rs2V.GetN(),

		imm32: ies.imm32.GetN(),
		func3: ies.func3.GetN(),

		pcPlus4: ies.pcPlus4.GetN(),
	}
}
