package pipeline

import (
	"fmt"
	. "riscv/system_interface"
)

type DecodeParams struct {
	regFile          *[32]RUint32
	shouldStall      func() bool
	getFetchValuesIn func() FetchValues
}

func NewDecodeParams(regFile *[32]RUint32, shouldStall func() bool, getFetchValuesIn func() FetchValues) *DecodeParams {
	return &DecodeParams{
		regFile:          regFile,
		shouldStall:      shouldStall,
		getFetchValuesIn: getFetchValuesIn,
	}
}

type DecodeStage struct {
	instruction RUint32

	isAluOp    RBool
	isStoreOp  RBool
	isLoadOp   RBool
	isLuiOp    RBool
	isJumpOp   RBool
	isJalOp    RBool
	isBranchOp RBool

	opcode RByte // 7 bits [6-0]
	rd     RByte // 5 bits [11-7]
	func3  RByte // 3 bits [14-12]
	func7  RByte // 7 bits [31-25]
	shamt  RByte // 5 bits [24-20] (for shift instructions)

	rs1V RUint32 // 5 bits [19-15]
	rs2V RUint32 // 5 bits [24-20]

	imm RInt32 // Sign-extend 12-bit immediate to 32 bits

	pc      RUint32
	pcPlus4 RUint32

	regFile *[32]RUint32

	shouldStall      func() bool
	getInstructionIn func() FetchValues
}

func NewDecodeStage(params *DecodeParams) *DecodeStage {

	ids := &DecodeStage{}

	ids.regFile = params.regFile
	ids.shouldStall = params.shouldStall
	ids.getInstructionIn = params.getFetchValuesIn
	return ids
}

func (ids *DecodeStage) Compute() {
	if !ids.shouldStall() {
		// fmt.Println("@ DECODE")

		fv := ids.getInstructionIn()
		ins := fv.Instruction
		ids.instruction.SetN(ins)

		ids.opcode.SetN(byte(ins & 0x7F))
		opcode := ids.opcode.GetN()

		ids.pc.SetN(fv.pc)
		ids.pcPlus4.SetN(fv.pcPlus4)

		ids.isAluOp.SetN(opcode&0b1011111 == 0b0010011)
		ids.isStoreOp.SetN(opcode == 0b0100011)
		ids.isLoadOp.SetN(opcode == 0b0000011)
		ids.isLuiOp.SetN(opcode == 0b0110111)
		ids.isJumpOp.SetN(opcode == JAL_OPCODE || opcode == JALR_OPCODE)
		ids.isJalOp.SetN(opcode == JAL_OPCODE)
		ids.isBranchOp.SetN(opcode == BRANCH_OPCODE)

		ids.rd.SetN(byte((ins >> 7) & 0x1F))

		ids.func3.SetN(byte((ins >> 12) & 0x07))

		rs1Address := byte((ins >> 15) & 0x1F)
		rs2Address := byte((ins >> 20) & 0x1F)

		ids.shamt.SetN(rs2Address)

		ids.rs1V.SetN(0)
		if rs1Address != 0 {
			ids.rs1V.SetN(ids.regFile[rs1Address].GetN())
		}
		ids.rs2V.SetN(0)
		if rs2Address != 0 {
			ids.rs2V.SetN(ids.regFile[rs2Address].GetN())
		}

		decodedIns := Decode(ins)
		if decodedIns != nil {
			fmt.Print(decodedIns.String())
		} else {
			fmt.Printf("$ Unknown instruction: 0x%08X\n", ins)
		}

		switch ins := decodedIns.(type) {
		case I_INS:
			{
				ids.imm.SetN(ins.Imm)

				if ids.isJumpOp.GetN() {
					// ids.branchAddress.SetN(uint32(int32(ids.rs1V.GetN()) + ins.Imm))
					// fmt.Printf(" [JALR] target=0x%08X", ids.branchAddress.GetN())
					fmt.Print(" JALR ")
				}
			}
		case R_INS:
			{
				ids.func7.SetN(ins.Funct7)
			}
		case S_INS:
			{
				ids.imm.SetN(ins.Imm)
			}
		case U_INS:
			{
				ids.imm.SetN(ins.Imm)
			}
		case J_INS:
			{
				ids.imm.SetN(ins.Imm)
				if ids.isJalOp.GetN() {
					// ids.branchAddress.SetN(uint32(int32(fv.pc) + ins.Imm))
					// fmt.Printf(" [JAL] target=0x%08X", ids.branchAddress.GetN())
					fmt.Print(" JAL ")
				}
			}
		case B_INS:
			{
				ids.imm.SetN(ins.Imm)
			}
		default:
			{
				panic(fmt.Sprintf("Unhandled instruction type for decoding immediate: 0x%08X", ins))
			}
		}

		fmt.Print(" => ")
	}
}

func (ids *DecodeStage) LatchNext() {
	ids.instruction.LatchNext()

	ids.opcode.LatchNext()
	ids.isAluOp.LatchNext()
	ids.isStoreOp.LatchNext()
	ids.isLoadOp.LatchNext()
	ids.isLuiOp.LatchNext()
	ids.isJumpOp.LatchNext()
	ids.isJalOp.LatchNext()
	ids.isBranchOp.LatchNext()

	ids.rd.LatchNext()

	ids.func3.LatchNext()
	ids.func7.LatchNext()

	ids.rs1V.LatchNext()
	ids.rs2V.LatchNext()
	ids.shamt.LatchNext()

	ids.imm.LatchNext()

	ids.pc.LatchNext()
	ids.pcPlus4.LatchNext()
}

type DecodedValues struct {
	opcode     byte
	isAluOp    bool
	isStoreOp  bool
	isLoadOp   bool
	isLuiOp    bool
	IsJumpOp   bool
	IsJalOp    bool
	isBranchOp bool

	rd    byte
	func3 byte
	func7 byte
	rs1V  uint32
	rs2V  uint32
	shamt byte

	imm int32

	pc      uint32
	pcPlus4 uint32
}

func (ids *DecodeStage) GetDecodedValuesOut() DecodedValues {
	return DecodedValues{
		opcode:     ids.opcode.GetN(),
		isAluOp:    ids.isAluOp.GetN(),
		isStoreOp:  ids.isStoreOp.GetN(),
		isLoadOp:   ids.isLoadOp.GetN(),
		isLuiOp:    ids.isLuiOp.GetN(),
		IsJumpOp:   ids.isJumpOp.GetN(),
		IsJalOp:    ids.isJalOp.GetN(),
		isBranchOp: ids.isBranchOp.GetN(),

		rd:    ids.rd.GetN(),
		func3: ids.func3.GetN(),
		func7: ids.func7.GetN(),
		rs1V:  ids.rs1V.GetN(),
		rs2V:  ids.rs2V.GetN(),
		shamt: ids.shamt.GetN(),

		imm: ids.imm.GetN(),

		pc:      ids.pc.GetN(),
		pcPlus4: ids.pcPlus4.GetN(),
	}
}
