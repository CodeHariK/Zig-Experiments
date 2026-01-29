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

	isAluOperation   RBool
	isStoreOperation RBool
	isLoadOperation  RBool
	isLUIOperation   RBool
	isJALOperation   RBool
	isJALROperation  RBool

	opcode RByte // 7 bits [6-0]
	rd     RByte // 5 bits [11-7]
	func3  RByte // 3 bits [14-12]
	func7  RByte // 7 bits [31-25]
	shamt  RByte // 5 bits [24-20] (for shift instructions)

	rs1V RUint32 // 5 bits [19-15]
	rs2V RUint32 // 5 bits [24-20]

	imm32 RInt32 // Sign-extend 12-bit immediate to 32 bits

	branchAddress RUint32 // Calculated branch address
	pc            RUint32
	pcPlus4       RUint32

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
		fv := ids.getInstructionIn()
		ins := fv.Instruction
		ids.instruction.SetN(ins)

		ids.opcode.SetN(byte(ins & 0x7F))
		opcode := ids.opcode.GetN()

		ids.pc.SetN(fv.pc)
		ids.pcPlus4.SetN(fv.pcPlus4)

		ids.isAluOperation.SetN(opcode&0b1011111 == 0b0010011)
		ids.isStoreOperation.SetN(opcode == 0b0100011)
		ids.isLoadOperation.SetN(opcode == 0b0000011)
		ids.isLUIOperation.SetN(opcode == 0b0110111)
		ids.isJALOperation.SetN(opcode == JAL_OPCODE)
		ids.isJALROperation.SetN(opcode == JALR_OPCODE)

		ids.rd.SetN(byte((ins >> 7) & 0x1F))

		ids.func3.SetN(byte((ins >> 12) & 0x07))
		ids.func7.SetN(byte((ins >> 25) & 0x7F))

		rs1Address := byte((ins >> 15) & 0x1F)
		rs2Address := byte((ins >> 20) & 0x1F)

		ids.shamt.SetN(rs2Address) // For shift instructions, shamt is in rs2 field

		ids.rs1V.SetN(0)
		if rs1Address != 0 {
			ids.rs1V.SetN(ids.regFile[rs1Address].GetN())
		}
		ids.rs2V.SetN(0)
		if rs2Address != 0 {
			ids.rs2V.SetN(ids.regFile[rs2Address].GetN())
		}

		// Immediate extraction for I-type instructions
		imm_11_0 := int32(ins) >> 20
		// Immediate extraction for S-type instructions
		imm_4_0 := int32((ins >> 7) & 0x1F)
		imm_11_5 := (int32((ins >> 25) & 0x7F))

		sImm := (imm_11_5 << 5) | imm_4_0
		iImm := (imm_11_0 << 20) >> 20
		uImm := ins & 0xFFFFF000

		jins := JTypeDecode(ins)

		if ids.isStoreOperation.GetN() {
			ids.imm32.SetN(sImm)
		} else if ids.isAluOperation.GetN() || ids.isLoadOperation.GetN() {
			ids.imm32.SetN(iImm)
		} else if ids.isLUIOperation.GetN() {
			ids.imm32.SetN(int32(uImm))
		} else if ids.isJALOperation.GetN() {
			ids.imm32.SetN(jins.imm32)
			ids.branchAddress.SetN(uint32(int32(fv.pc) + jins.imm32))
		} else if ids.isJALROperation.GetN() {
			ids.imm32.SetN(iImm)
			ids.branchAddress.SetN(uint32(int32(ids.rs1V.GetN()) + iImm))
		} else {
			panic(fmt.Sprintf("Unknown operation 0x%x", ins))
		}
	}
}

func (ids *DecodeStage) LatchNext() {
	ids.instruction.LatchNext()

	ids.opcode.LatchNext()
	ids.isAluOperation.LatchNext()
	ids.isStoreOperation.LatchNext()
	ids.isLoadOperation.LatchNext()
	ids.isLUIOperation.LatchNext()
	ids.isJALOperation.LatchNext()
	ids.isJALROperation.LatchNext()

	ids.rd.LatchNext()

	ids.func3.LatchNext()
	ids.func7.LatchNext()

	ids.rs1V.LatchNext()
	ids.rs2V.LatchNext()
	ids.shamt.LatchNext()

	ids.imm32.LatchNext()
	ids.branchAddress.LatchNext()

	ids.pc.LatchNext()
	ids.pcPlus4.LatchNext()
}

type DecodedValues struct {
	Opcode           byte
	IsAluOperation   bool
	IsStoreOperation bool
	IsLoadOperation  bool
	isLUIOperation   bool
	IsJALOperation   bool
	IsJALROperation  bool

	Rd      byte
	Func3   byte
	Func7   byte
	Rs1V    uint32
	Rs2V    uint32
	Rs1Addr byte
	Rs2Addr byte
	Shamt   byte

	Imm32 int32

	BranchAddress uint32
	pc            uint32
	pcPlus4       uint32
}

func (ids *DecodeStage) GetDecodedValuesOut() DecodedValues {
	return DecodedValues{
		Opcode:           ids.opcode.GetN(),
		IsAluOperation:   ids.isAluOperation.GetN(),
		IsStoreOperation: ids.isStoreOperation.GetN(),
		IsLoadOperation:  ids.isLoadOperation.GetN(),
		isLUIOperation:   ids.isLUIOperation.GetN(),
		IsJALOperation:   ids.isJALOperation.GetN(),
		IsJALROperation:  ids.isJALROperation.GetN(),

		Rd:    ids.rd.GetN(),
		Func3: ids.func3.GetN(),
		Func7: ids.func7.GetN(),
		Rs1V:  ids.rs1V.GetN(),
		Rs2V:  ids.rs2V.GetN(),
		Shamt: ids.shamt.GetN(),

		Imm32: ids.imm32.GetN(),

		BranchAddress: ids.branchAddress.GetN(),
		pc:            ids.pc.GetN(),
		pcPlus4:       ids.pcPlus4.GetN(),
	}
}
