package pipeline

import . "riscv/system_interface"

type DecodeParams struct {
	regFile          *[32]RUint32
	shouldStall      func() bool
	getInstructionIn func() uint32
}

func NewDecodeParams(regFile *[32]RUint32, shouldStall func() bool, getInstructionIn func() uint32) *DecodeParams {
	return &DecodeParams{
		regFile:          regFile,
		shouldStall:      shouldStall,
		getInstructionIn: getInstructionIn,
	}
}

type DecodeStage struct {
	instruction RUint32

	isAluOperation   RBool // R-type or I-type ALU operation
	isStoreOperation RBool // S-type store operation

	opcode RByte // 7 bits [6-0]
	rd     RByte // 5 bits [11-7]
	func3  RByte // 3 bits [14-12]
	func7  RByte // 7 bits [31-25]
	shamt  RByte // 5 bits [24-20] (for shift instructions)

	rs1V RUint32 // 5 bits [19-15]
	rs2V RUint32 // 5 bits [24-20]

	imm_11_0  RInt32 // Sign-extend 12-bits [31-20] signed integer for arithmetic shift
	imm_31_12 RInt32 // 20 bits [31-12]
	imm_11_5  RInt32 // 7 bits [31-25]
	imm_4_0   RInt32 // 5 bits [11-7]

	imm32 RInt32 // Sign-extend 12-bit immediate to 32 bits

	regFile *[32]RUint32

	shouldStall      func() bool
	getInstructionIn func() uint32
}

func NewDecodeStage(params *DecodeParams) *DecodeStage {

	ids := &DecodeStage{}

	ids.instruction = NewRUint32(0)

	ids.isAluOperation = NewRBool(false)
	ids.isStoreOperation = NewRBool(false)

	ids.opcode = NewRByte(0)

	ids.rd = NewRByte(0)

	ids.func3 = NewRByte(0)
	ids.func7 = NewRByte(0)

	ids.rs1V = NewRUint32(0)
	ids.rs2V = NewRUint32(0)

	ids.shamt = NewRByte(0)

	ids.imm_11_0 = NewRInt32(0)
	ids.imm_31_12 = NewRInt32(0)
	ids.imm_11_5 = NewRInt32(0)
	ids.imm_4_0 = NewRInt32(0)

	ids.regFile = params.regFile
	ids.shouldStall = params.shouldStall
	ids.getInstructionIn = params.getInstructionIn
	return ids
}

func (ids *DecodeStage) Compute() {
	if !ids.shouldStall() {
		ids.instruction.SetN(ids.getInstructionIn())

		ids.opcode.SetN(byte(ids.instruction.GetN() & 0x7F))
		ids.isAluOperation.SetN(ids.opcode.GetN()&0b1011111 == 0b0010011)
		ids.isStoreOperation.SetN(ids.opcode.GetN() == 0b0100011)

		ids.rd.SetN(byte((ids.instruction.GetN() >> 7) & 0x1F))

		ids.func3.SetN(byte((ids.instruction.GetN() >> 12) & 0x07))
		ids.func7.SetN(byte((ids.instruction.GetN() >> 25) & 0x7F))

		rs1Address := byte((ids.instruction.GetN() >> 15) & 0x1F)
		rs2Address := byte((ids.instruction.GetN() >> 20) & 0x1F)

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
		ids.imm_11_0.SetN(int32(ids.instruction.GetN()) >> 20)

		// Immediate extraction for U-type instructions
		ids.imm_31_12.SetN(int32(ids.instruction.GetN() & 0xFFFFF000))

		// Immediate extraction for S-type instructions
		ids.imm_4_0.SetN(int32((ids.instruction.GetN() >> 7) & 0x1F))
		ids.imm_11_5.SetN(int32((ids.instruction.GetN() >> 25) & 0x7F))

		storeImm := (ids.imm_11_5.GetN() << 5) | ids.imm_4_0.GetN()
		aluImm := (ids.imm_11_0.GetN() << 20) >> 20

		if ids.isStoreOperation.GetN() {
			ids.imm32.SetN(storeImm)
		} else if ids.isAluOperation.GetN() {
			ids.imm32.SetN(aluImm)
		} else {
			panic("Unknown operation")
		}
	}
}

func (ids *DecodeStage) LatchNext() {
	ids.instruction.LatchNext()

	ids.opcode.LatchNext()
	ids.isAluOperation.LatchNext()
	ids.isStoreOperation.LatchNext()

	ids.rd.LatchNext()

	ids.func3.LatchNext()
	ids.func7.LatchNext()

	ids.rs1V.LatchNext()
	ids.rs2V.LatchNext()
	ids.shamt.LatchNext() // For shift instructions, shamt is in rs2 field

	// Immediate extraction for I-type instructions
	ids.imm_11_0.LatchNext()

	// Immediate extraction for U-type instructions
	ids.imm_31_12.LatchNext()

	// Immediate extraction for S-type instructions
	ids.imm_4_0.LatchNext()
	ids.imm_11_5.LatchNext()
}

type DecodedValues struct {
	Opcode           byte
	IsAluOperation   bool
	IsStoreOperation bool

	Rd        byte
	Func3     byte
	Func7     byte
	Rs1V      uint32
	Rs2V      uint32
	Shamt     byte
	Imm_11_0  int32
	Imm_31_12 int32
	Imm_11_5  int32
	Imm_4_0   int32

	Imm32 int32
}

func (ids *DecodeStage) GetDecodedValues() DecodedValues {
	return DecodedValues{
		Opcode:           ids.opcode.GetN(),
		IsAluOperation:   ids.isAluOperation.GetN(),
		IsStoreOperation: ids.isStoreOperation.GetN(),

		Rd:        ids.rd.GetN(),
		Func3:     ids.func3.GetN(),
		Func7:     ids.func7.GetN(),
		Rs1V:      ids.rs1V.GetN(),
		Rs2V:      ids.rs2V.GetN(),
		Shamt:     ids.shamt.GetN(),
		Imm_11_0:  ids.imm_11_0.GetN(),
		Imm_31_12: ids.imm_31_12.GetN(),
		Imm_11_5:  ids.imm_11_5.GetN(),
		Imm_4_0:   ids.imm_4_0.GetN(),

		Imm32: ids.imm32.GetN(),
	}
}
