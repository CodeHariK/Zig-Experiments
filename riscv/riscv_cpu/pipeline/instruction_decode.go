package pipeline

import . "riscv/system_interface"

type DecodeParams struct {
	regFile          *[32]Register32
	shouldStall      func() bool
	getInstructionIn func() uint32
}

func NewDecodeParams(regFile *[32]Register32, shouldStall func() bool, getInstructionIn func() uint32) *DecodeParams {
	return &DecodeParams{
		regFile:          regFile,
		shouldStall:      shouldStall,
		getInstructionIn: getInstructionIn,
	}
}

type DecodeStage struct {
	instruction     Register32
	instructionNext Register32

	opcode     byte // 7 bits [6-0]
	opcodeNext byte

	rd     byte // 5 bits [11-7]
	rdNext byte

	function3     byte // 3 bits [14-12]
	function3Next byte
	function7     byte // 7 bits [31-25]
	function7Next byte

	rs1       uint32 // 5 bits [19-15]
	rs1Next   uint32
	rs2       uint32 // 5 bits [24-20]
	rs2Next   uint32
	shamt     byte // 5 bits [24-20] (for shift instructions)
	shamtNext byte

	imm_11_0       int32 // Sign-extend 12-bits [31-20] signed integer for arithmetic shift
	imm_11_0_Next  int32
	imm_31_12      int32 // 20 bits [31-12]
	imm_31_12_Next int32
	imm_11_5       int32 // 7 bits [31-25]
	imm_11_5_Next  int32
	imm_4_0        int32 // 5 bits [11-7]
	imm_4_0_Next   int32

	regFile *[32]Register32

	shouldStall      func() bool
	getInstructionIn func() uint32
}

func NewDecodeStage(params *DecodeParams) *DecodeStage {

	ids := &DecodeStage{}

	ids.instruction = Register32{Value: 0}
	ids.instructionNext = Register32{Value: 0}

	ids.opcode = 0
	ids.opcodeNext = 0

	ids.rd = 0
	ids.rdNext = 0

	ids.function3 = 0
	ids.function3Next = 0
	ids.function7 = 0
	ids.function7Next = 0

	ids.rs1 = 0
	ids.rs1Next = 0
	ids.rs2 = 0
	ids.rs2Next = 0

	ids.shamt = 0
	ids.shamtNext = 0

	ids.imm_11_0 = 0
	ids.imm_11_0_Next = 0

	ids.imm_31_12 = 0
	ids.imm_31_12_Next = 0

	ids.imm_11_5 = 0
	ids.imm_11_5_Next = 0
	ids.imm_4_0 = 0
	ids.imm_4_0_Next = 0

	ids.regFile = params.regFile
	ids.shouldStall = params.shouldStall
	ids.getInstructionIn = params.getInstructionIn
	return ids
}

func (ids *DecodeStage) Compute() {
	if !ids.shouldStall() {
		ids.instructionNext.Value = ids.getInstructionIn()

		ids.opcodeNext = byte(ids.instructionNext.Value & 0x7F)

		ids.rdNext = byte((ids.instructionNext.Value >> 7) & 0x1F)

		ids.function3Next = byte((ids.instructionNext.Value >> 12) & 0x07)
		ids.function7Next = byte((ids.instructionNext.Value >> 25) & 0x7F)

		rs1Address := byte((ids.instructionNext.Value >> 15) & 0x1F)
		rs2Address := byte((ids.instructionNext.Value >> 20) & 0x1F)
		ids.shamtNext = rs2Address // For shift instructions, shamt is in rs2 field
		ids.rs1Next = 0
		if rs1Address != 0 {
			ids.rs1Next = ids.regFile[rs1Address].Value
		}
		ids.rs2Next = 0
		if rs2Address != 0 {
			ids.rs2Next = ids.regFile[rs2Address].Value
		}

		// Immediate extraction for I-type instructions
		ids.imm_11_0_Next = int32(ids.instructionNext.Value) >> 20

		// Immediate extraction for U-type instructions
		ids.imm_31_12_Next = int32(ids.instructionNext.Value & 0xFFFFF000)

		// Immediate extraction for S-type instructions
		ids.imm_4_0_Next = int32((ids.instructionNext.Value >> 7) & 0x1F)
		ids.imm_11_5_Next = int32((ids.instructionNext.Value >> 25) & 0x7F)
	}
}

func (ids *DecodeStage) LatchNext() {
	ids.instruction.Value = ids.instructionNext.Value
	ids.opcode = ids.opcodeNext

	ids.rd = ids.rdNext

	ids.function3 = ids.function3Next
	ids.function7 = ids.function7Next

	ids.rs1 = ids.rs1Next
	ids.rs2 = ids.rs2Next
	ids.shamt = ids.shamtNext // For shift instructions, shamt is in rs2 field

	// Immediate extraction for I-type instructions
	ids.imm_11_0 = ids.imm_11_0_Next

	// Immediate extraction for U-type instructions
	ids.imm_31_12 = ids.imm_31_12_Next

	// Immediate extraction for S-type instructions
	ids.imm_4_0 = ids.imm_4_0_Next
	ids.imm_11_5 = ids.imm_11_5_Next
}

type DecodedValues struct {
	Opcode    byte
	Rd        byte
	Function3 byte
	Function7 byte
	Rs1       uint32
	Rs2       uint32
	Shamt     byte
	Imm_11_0  int32
	Imm_31_12 int32
	Imm_11_5  int32
	Imm_4_0   int32
}

func (ids *DecodeStage) GetDecodedValues() DecodedValues {
	return DecodedValues{
		Opcode:    ids.opcode,
		Rd:        ids.rd,
		Function3: ids.function3,
		Function7: ids.function7,
		Rs1:       ids.rs1,
		Rs2:       ids.rs2,
		Shamt:     ids.shamt,
		Imm_11_0:  ids.imm_11_0,
		Imm_31_12: ids.imm_31_12,
		Imm_11_5:  ids.imm_11_5,
		Imm_4_0:   ids.imm_4_0,
	}
}
