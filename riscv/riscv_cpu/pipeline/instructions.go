package pipeline

import "fmt"

const REGISTER_OPCODE = 0b0110011
const IMMEDIATE_OPCODE = 0b0010011
const LOAD_OPCODE = 0b0000011
const STORE_OPCODE = 0b0100011
const JAL_OPCODE = 0b1101111
const JALR_OPCODE = 0b1100111

func Bits(v uint32, lo, hi uint) uint32 {
	return (v >> lo) & ((1 << (hi - lo + 1)) - 1)
}

func SignExtend(v uint32, bits uint) int32 {
	shift := 32 - bits
	return int32(v<<shift) >> shift
}

type Instruction interface {
	Encode() uint32
	String() string
}

type I_INS struct {
	Name   string
	Opcode byte
	Rd     byte
	Funct3 byte
	Rs1    byte
	Imm    int32
}

func (i I_INS) Encode() uint32 {
	return uint32(i.Opcode) |
		uint32(i.Rd)<<7 |
		uint32(i.Funct3)<<12 |
		uint32(i.Rs1)<<15 |
		uint32(i.Imm&0xFFF)<<20
}

func (i I_INS) String() string {
	return fmt.Sprintf("I-Type: %s Rd=x%d, Funct3=0b%03b, Rs1=x%d, Imm=%d",
		i.Name, i.Rd, i.Funct3, i.Rs1, i.Imm)
}

type R_INS struct {
	Name   string
	Opcode byte
	Rd     byte
	Funct3 byte
	Rs1    byte
	Rs2    byte
	Funct7 byte
}

func (r R_INS) Encode() uint32 {
	return uint32(r.Opcode) |
		uint32(r.Rd)<<7 |
		uint32(r.Funct3)<<12 |
		uint32(r.Rs1)<<15 |
		uint32(r.Rs2)<<20 |
		uint32(r.Funct7)<<25
}

func (r R_INS) String() string {
	return fmt.Sprintf("R-Type: %s  Rd=x%d, Funct3=0b%03b, Rs1=x%d, Rs2=x%d, Funct7=0b%07b",
		r.Name, r.Rd, r.Funct3, r.Rs1, r.Rs2, r.Funct7)
}

type U_INS struct {
	Name   string
	Opcode uint8
	Rd     uint8
	Imm    int32 // full 32-bit immediate (already << 12)
}

func (u U_INS) Encode() uint32 {
	return ((uint32(u.Imm) & 0xFFFFF) << 12) |
		(uint32(u.Rd)&0x1F)<<7 |
		uint32(u.Opcode&0x7F)
}

func (u U_INS) String() string {
	return fmt.Sprintf("U-Type: %s x%d, 0x%x", u.Name, u.Rd, u.Imm>>12)
}

type S_INS struct {
	Name   string
	Opcode uint8
	Funct3 uint8
	Rs1    uint8
	Rs2    uint8
	Imm    int32
}

func (s S_INS) Encode() uint32 {
	imm := uint32(s.Imm) & 0xFFF

	return uint32(s.Opcode) |
		(imm&0x1F)<<7 | // imm[4:0]
		uint32(s.Funct3)<<12 |
		uint32(s.Rs1)<<15 |
		uint32(s.Rs2)<<20 |
		(imm>>5)<<25 // imm[11:5]
}

func (s S_INS) String() string {
	return fmt.Sprintf("S-Type: %s x%d, %d(x%d)",
		s.Name, s.Rs2, s.Imm, s.Rs1)
}

type J_INS struct {
	Name string
	/*
		RISC-V jumps are always 2-byte aligned, so bit 0 is always 0.
		Sign-extended 21-bit immediate to 32 bits
	*/
	Imm    int32
	Rd     byte
	Opcode byte
}

func (j J_INS) Encode() uint32 {
	imm := uint32(j.Imm)
	imm20 := (imm >> 20) & 0x1     // 1 bit
	imm10_1 := (imm >> 1) & 0x3FF  // 10 bits
	imm11 := (imm >> 11) & 0x1     // 1 bit
	imm19_12 := (imm >> 12) & 0xFF // 8 bits
	return uint32(j.Opcode) |
		uint32(j.Rd)<<7 |
		uint32(imm19_12)<<12 |
		uint32(imm11)<<20 |
		uint32(imm10_1)<<21 |
		uint32(imm20)<<31
}

func (j J_INS) String() string {
	return fmt.Sprintf("J-Type: %s Rd=x%d, Imm=%d",
		j.Name, j.Rd, j.Imm)
}

func Decode(instr uint32) Instruction {
	opcode := Bits(instr, 0, 6)

	switch opcode {

	case 0x13, LOAD_OPCODE, JALR_OPCODE: // I-Type (e.g. ADDI, LW)
		return I_INS{
			Opcode: uint8(opcode),
			Rd:     uint8(Bits(instr, 7, 11)),
			Funct3: uint8(Bits(instr, 12, 14)),
			Rs1:    uint8(Bits(instr, 15, 19)),
			Imm:    SignExtend(Bits(instr, 20, 31), 12),
		}

	case 0x33: // R-Type (e.g. ADD)
		return R_INS{
			Opcode: uint8(opcode),
			Rd:     uint8(Bits(instr, 7, 11)),
			Funct3: uint8(Bits(instr, 12, 14)),
			Rs1:    uint8(Bits(instr, 15, 19)),
			Rs2:    uint8(Bits(instr, 20, 24)),
			Funct7: uint8(Bits(instr, 25, 31)),
		}

	case 0x37, 0x17: // U-Type (LUI, AUIPC)
		imm := Bits(instr, 12, 31) << 12

		return U_INS{
			Opcode: uint8(opcode),
			Rd:     uint8(Bits(instr, 7, 11)),
			Imm:    int32(imm),
		}

	case 0x23: // S-Type (SB, SH, SW)
		imm :=
			(Bits(instr, 25, 31) << 5) |
				Bits(instr, 7, 11)

		return S_INS{
			Opcode: uint8(opcode),
			Funct3: uint8(Bits(instr, 12, 14)),
			Rs1:    uint8(Bits(instr, 15, 19)),
			Rs2:    uint8(Bits(instr, 20, 24)),
			Imm:    SignExtend(imm, 12),
		}

	case JAL_OPCODE: // J-Type (JAL)
		imm :=
			(Bits(instr, 31, 31) << 20) |
				(Bits(instr, 21, 30) << 1) |
				(Bits(instr, 20, 20) << 11) |
				(Bits(instr, 12, 19) << 12)

		return J_INS{
			Opcode: uint8(opcode),
			Rd:     uint8(Bits(instr, 7, 11)),
			Imm:    SignExtend(imm, 21),
		}

	}

	return nil
}

// funct7 rs2 rs1 funct3 rd opcode
func RType(name string, rd byte, rs1 byte, rs2_shamt byte, func7 byte, func3 byte, opcode byte) uint32 {
	ins := R_INS{
		Name:   name,
		Opcode: opcode,
		Rd:     rd,
		Funct3: func3,
		Rs1:    rs1,
		Rs2:    rs2_shamt,
		Funct7: func7,
	}
	return ins.Encode()

	// return (uint32(func7)&0x7F)<<25 |
	// 	(uint32(rs2_shamt)&0x1F)<<20 |
	// 	(uint32(rs1)&0x1F)<<15 |
	// 	(uint32(func3)&0x7)<<12 |
	// 	(uint32(rd)&0x1F)<<7 |
	// 	uint32(opcode&0x7F)
}

// imm[11:0] rs1 funct3 rd opcode
func IType(name string, rd byte, rs1 byte, imm int32, func3 byte, opcode byte) uint32 {

	ins := I_INS{
		Name:   name,
		Opcode: opcode,
		Rd:     rd,
		Funct3: func3,
		Rs1:    rs1,
		Imm:    imm,
	}

	return ins.Encode()

	// return (uint32(imm)&0xFFF)<<20 |
	// 	(uint32(rs1)&0x1F)<<15 |
	// 	(uint32(func3)&0x7)<<12 |
	// 	(uint32(rd)&0x1F)<<7 |
	// 	uint32(opcode&0x7F)
}

// imm[11:5] rs2 rs1 funct3 imm[4:0] opcode
func SType(name string, rs1 byte, rs2 byte, imm int32, func3 byte, opcode byte) uint32 {

	ins := S_INS{
		Name:   name,
		Opcode: opcode,
		Funct3: func3,
		Rs1:    rs1,
		Rs2:    rs2,
		Imm:    imm,
	}

	return ins.Encode()

	// imm11_5 := (imm >> 5) & 0x7F
	// imm4_0 := imm & 0x1F
	// return (uint32(imm11_5)&0x7F)<<25 |
	// 	(uint32(rs2)&0x1F)<<20 |
	// 	(uint32(rs1)&0x1F)<<15 |
	// 	(uint32(func3)&0x7)<<12 |
	// 	(uint32(imm4_0)&0x1F)<<7 |
	// 	uint32(opcode&0x7F)
}

// imm[20|10:1|11|19:12] rd opcode J-type
func JType(name string, rd byte, imm int32, opcode byte) uint32 {

	ins := J_INS{
		Name:   name,
		Opcode: opcode,
		Rd:     rd,
		Imm:    imm,
	}
	return ins.Encode()

	// imm20 := (imm >> 20) & 0x1     // 1 bit
	// imm10_1 := (imm >> 1) & 0x3FF  // 10 bits
	// imm11 := (imm >> 11) & 0x1     // 1 bit
	// imm19_12 := (imm >> 12) & 0xFF // 8 bits
	// return uint32(imm20)<<31 |
	// 	uint32(imm10_1)<<21 |
	// 	uint32(imm11)<<20 |
	// 	uint32(imm19_12)<<12 |
	// 	(uint32(rd)&0x1F)<<7 |
	// 	uint32(opcode&0x7F)
}

// func JTypeDecode(instruction uint32) J_INS {

// 	imm20 := (int32(instruction) >> 31) & 0x1     // 1 bit
// 	imm10_1 := (int32(instruction) >> 21) & 0x3FF // 10 bits
// 	imm11 := (int32(instruction) >> 20) & 0x1     // 1 bit
// 	imm19_12 := (int32(instruction) >> 12) & 0xFF // 8 bits

// 	// 21-bit immediate construction, implicitly with 0 as LSB
// 	imm := (imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1)

// 	// Sign-extend to 32 bits
// 	imm = imm << 11 >> 11

// 	return J_INS{
// 		Imm:    imm,
// 		Rd:     byte((instruction >> 7) & 0x1F),
// 		Opcode: byte(instruction & 0x7F),
// 	}
// }

// imm[31:12] rd opcode
func UType(name string, rd byte, imm int32, opcode byte) uint32 {

	ins := U_INS{
		Name:   name,
		Opcode: opcode,
		Rd:     rd,
		Imm:    imm,
	}
	return ins.Encode()

	// return ((uint32(imm) & 0xFFFFF) << 12) |
	// 	(uint32(rd)&0x1F)<<7 |
	// 	uint32(opcode&0x7F)
}

// x[rd] = x[rs1] + sign-extended(immediate)
func ADDI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 000 rd 0010011
	return IType("ADDI", rd, rs1, imm, 0b000, IMMEDIATE_OPCODE)
}

// x[rd] = x[rs1] + x[rs2]
func ADD(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 000 rd 0110011
	return RType("ADD", rd, rs1, rs2, 0b0000000, 0b000, REGISTER_OPCODE)
}

// x[rd] = x[rs1] - x[rs2]
func SUB(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0100000 rs2 rs1 000 rd 0110011
	return RType("SUB", rd, rs1, rs2, 0b0100000, 0b000, REGISTER_OPCODE)
}

// x[rd] = x[rs1] << (x[rs2] & 0x1F)
func SLL(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 001 rd 0110011
	return RType("SLL", rd, rs1, rs2, 0b0000000, 0b001, REGISTER_OPCODE)
}

// x[rd] = x[rs1] << shamt
func SLLI(rd byte, rs1 byte, shamt byte) uint32 {
	// 0000000 shamt rs1 001 rd 0010011
	return RType("SLLI", rd, rs1, shamt, 0b0000000, 0b001, IMMEDIATE_OPCODE)
}

// x[rd] = (int32(x[rs1]) < int32(x[rs2])) ? 1 : 0
func SLT(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 010 rd 0110011
	return RType("SLT", rd, rs1, rs2, 0b0000000, 0b010, REGISTER_OPCODE)
}

// x[rd] = (int32(x[rs1]) < sign-extended(immediate)) ? 1 : 0
func SLTI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 010 rd 0010011
	return IType("SLTI", rd, rs1, imm, 0b010, IMMEDIATE_OPCODE)
}

// x[rd] = (x[rs1] < x[rs2]) ? 1 : 0
func SLTU(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 011 rd 0110011
	return RType("SLTU", rd, rs1, rs2, 0b0000000, 0b011, REGISTER_OPCODE)
}

// x[rd] = (x[rs1] < uint32(immediate)) ? 1 : 0
func SLTIU(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 011 rd 0010011
	return IType("SLTIU", rd, rs1, imm, 0b011, IMMEDIATE_OPCODE)
}

// x[rd] = x[rs1] ^ x[rs2]
func XOR(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 100 rd 0110011
	return RType("XOR", rd, rs1, rs2, 0b0000000, 0b100, REGISTER_OPCODE)
}

// x[rd] = x[rs1] ^ sign-extended(immediate)
func XORI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 100 rd 0010011
	return IType("XORI", rd, rs1, imm, 0b100, IMMEDIATE_OPCODE)
}

// x[rd] = x[rs1] >> (x[rs2] & 0x1F)
func SRL(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 101 rd 0110011
	return RType("SRL", rd, rs1, rs2, 0b0000000, 0b101, REGISTER_OPCODE)
}

// x[rd] = x[rs1] >> shamt
func SRLI(rd byte, rs1 byte, shamt byte) uint32 {
	// 0000000 shamt rs1 101 rd 0010011
	return RType("SRLI", rd, rs1, shamt, 0b0000000, 0b101, IMMEDIATE_OPCODE)
}

// x[rd] = x[rs1] | x[rs2]
func OR(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 110 rd 0110011
	return RType("OR", rd, rs1, rs2, 0b0000000, 0b110, REGISTER_OPCODE)
}

// x[rd] = x[rs1] | sign-extended(immediate)
func ORI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 110 rd 0010011
	return IType("ORI", rd, rs1, imm, 0b110, IMMEDIATE_OPCODE)
}

// x[rd] = x[rs1] & x[rs2]
func AND(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 111 rd 0110011
	return RType("AND", rd, rs1, rs2, 0b0000000, 0b111, REGISTER_OPCODE)
}

// x[rd] = x[rs1] & sign-extended(immediate)
func ANDI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 111 rd 0010011
	return IType("ANDI", rd, rs1, imm, 0b111, IMMEDIATE_OPCODE)
}

// Mem[rs1 + imm] = rs2[7:0]
func SB(rs1 byte, rs2 byte, imm int32) uint32 {
	// imm[11:5] rs2 rs1 000 imm[4:0] 0100011
	return SType("SB", rs1, rs2, imm, 0b000, STORE_OPCODE)
}

// Mem[rs1 + imm] = rs2[15:0]
func SH(rs1 byte, rs2 byte, imm int32) uint32 {
	// imm[11:5] rs2 rs1 001 imm[4:0] 0100011
	return SType("SH", rs1, rs2, imm, 0b001, STORE_OPCODE)
}

// Mem[rs1 + imm] = rs2
func SW(rs1 byte, rs2 byte, imm int32) uint32 {
	// imm[11:5] rs2 rs1 010 imm[4:0] 0100011
	return SType("SW", rs1, rs2, imm, 0b010, STORE_OPCODE)
}

// x[rd] = sign-extended(Mem[rs1 + imm])
func LB(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 000 rd 0000011
	return IType("LB", rd, rs1, imm, 0b000, LOAD_OPCODE)
}

// x[rd] = sign-extended(Mem[rs1 + imm])
func LH(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 001 rd 0000011
	return IType("LH", rd, rs1, imm, 0b001, LOAD_OPCODE)
}

// x[rd] = Mem[rs1 + imm]
func LW(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 010 rd 0000011
	return IType("LW", rd, rs1, imm, 0b010, LOAD_OPCODE)
}

// x[rd] = zero-extended(Mem[rs1 + imm])
func LBU(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 100 rd 0000011
	return IType("LBU", rd, rs1, imm, 0b100, LOAD_OPCODE)
}

// x[rd] = zero-extended(Mem[rs1 + imm])
func LHU(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 101 rd 0000011
	return IType("LHU", rd, rs1, imm, 0b101, LOAD_OPCODE)
}

func LUI(rd byte, imm int32) uint32 {
	// imm[31:12] rd 0110111
	return UType("LUI", rd, imm, 0b0110111)
}

func AUIPC(rd byte, imm int32) uint32 {
	// imm[31:12] rd 0010111
	return UType("AUIPC", rd, imm, 0b0010111)
}

func JAL(rd byte, imm int32) uint32 {
	return JType("JAL", rd, imm, JAL_OPCODE)
}

func JALR(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 000 rd 1100111
	return IType("JALR", rd, rs1, imm, 0b000, JALR_OPCODE)
}
