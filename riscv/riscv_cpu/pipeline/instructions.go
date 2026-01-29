package pipeline

// funct7 rs2 rs1 funct3 rd opcode
func RType(rd byte, rs1 byte, rs2_shamt byte, func7 byte, func3 byte, opcode byte) uint32 {
	return (uint32(func7)&0x7F)<<25 |
		(uint32(rs2_shamt)&0x1F)<<20 |
		(uint32(rs1)&0x1F)<<15 |
		(uint32(func3)&0x7)<<12 |
		(uint32(rd)&0x1F)<<7 |
		uint32(opcode&0x7F)
}

// imm[11:0] rs1 funct3 rd opcode
func IType(rd byte, rs1 byte, imm int32, func3 byte, opcode byte) uint32 {
	return (uint32(imm)&0xFFF)<<20 |
		(uint32(rs1)&0x1F)<<15 |
		(uint32(func3)&0x7)<<12 |
		(uint32(rd)&0x1F)<<7 |
		uint32(opcode&0x7F)
}

// imm[11:5] rs2 rs1 funct3 imm[4:0] opcode
func SType(rs1 byte, rs2 byte, imm int32, func3 byte) uint32 {
	imm11_5 := (imm >> 5) & 0x7F
	imm4_0 := imm & 0x1F
	return (uint32(imm11_5)&0x7F)<<25 |
		(uint32(rs2)&0x1F)<<20 |
		(uint32(rs1)&0x1F)<<15 |
		(uint32(func3)&0x7)<<12 |
		(uint32(imm4_0)&0x1F)<<7 |
		0b0100011
}

// x[rd] = x[rs1] + sign-extended(immediate)
func ADDI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 000 rd 0010011
	return IType(rd, rs1, imm, 0b000, 0b0010011)
}

// x[rd] = x[rs1] + x[rs2]
func ADD(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 000 rd 0110011
	return RType(rd, rs1, rs2, 0b0000000, 0b000, 0b0110011)
}

// x[rd] = x[rs1] - x[rs2]
func SUB(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0100000 rs2 rs1 000 rd 0110011
	return RType(rd, rs1, rs2, 0b0100000, 0b000, 0b0110011)
}

// x[rd] = x[rs1] << (x[rs2] & 0x1F)
func SLL(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 001 rd 0110011
	return RType(rd, rs1, rs2, 0b0000000, 0b001, 0b0110011)
}

// x[rd] = x[rs1] << shamt
func SLLI(rd byte, rs1 byte, shamt byte) uint32 {
	// 0000000 shamt rs1 001 rd 0010011
	return RType(rd, rs1, shamt, 0b0000000, 0b001, 0b0010011)
}

// x[rd] = (int32(x[rs1]) < int32(x[rs2])) ? 1 : 0
func SLT(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 010 rd 0110011
	return RType(rd, rs1, rs2, 0b0000000, 0b010, 0b0110011)
}

// x[rd] = (int32(x[rs1]) < sign-extended(immediate)) ? 1 : 0
func SLTI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 010 rd 0010011
	return IType(rd, rs1, imm, 0b010, 0b0010011)
}

// x[rd] = (x[rs1] < x[rs2]) ? 1 : 0
func SLTU(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 011 rd 0110011
	return RType(rd, rs1, rs2, 0b0000000, 0b011, 0b0110011)
}

// x[rd] = (x[rs1] < uint32(immediate)) ? 1 : 0
func SLTIU(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 011 rd 0010011
	return IType(rd, rs1, imm, 0b011, 0b0010011)
}

// x[rd] = x[rs1] ^ x[rs2]
func XOR(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 100 rd 0110011
	return RType(rd, rs1, rs2, 0b0000000, 0b100, 0b0110011)
}

// x[rd] = x[rs1] ^ sign-extended(immediate)
func XORI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 100 rd 0010011
	return IType(rd, rs1, imm, 0b100, 0b0010011)
}

// x[rd] = x[rs1] >> (x[rs2] & 0x1F)
func SRL(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 101 rd 0110011
	return RType(rd, rs1, rs2, 0b0000000, 0b101, 0b0110011)
}

// x[rd] = x[rs1] >> shamt
func SRLI(rd byte, rs1 byte, shamt byte) uint32 {
	// 0000000 shamt rs1 101 rd 0010011
	return RType(rd, rs1, shamt, 0b0000000, 0b101, 0b0010011)
}

// x[rd] = x[rs1] | x[rs2]
func OR(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 110 rd 0110011
	return RType(rd, rs1, rs2, 0b0000000, 0b110, 0b0110011)
}

// x[rd] = x[rs1] | sign-extended(immediate)
func ORI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 110 rd 0010011
	return IType(rd, rs1, imm, 0b110, 0b0010011)
}

// x[rd] = x[rs1] & x[rs2]
func AND(rd byte, rs1 byte, rs2 byte) uint32 {
	// 0000000 rs2 rs1 111 rd 0110011
	return RType(rd, rs1, rs2, 0b0000000, 0b111, 0b0110011)
}

// x[rd] = x[rs1] & sign-extended(immediate)
func ANDI(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 111 rd 0010011
	return IType(rd, rs1, imm, 0b111, 0b0010011)
}

// Mem[rs1 + imm] = rs2[7:0]
func SB(rs1 byte, rs2 byte, imm int32) uint32 {
	// imm[11:5] rs2 rs1 000 imm[4:0] 0100011
	return SType(rs1, rs2, imm, 0b000)
}

// Mem[rs1 + imm] = rs2[15:0]
func SH(rs1 byte, rs2 byte, imm int32) uint32 {
	// imm[11:5] rs2 rs1 001 imm[4:0] 0100011
	return SType(rs1, rs2, imm, 0b001)
}

// Mem[rs1 + imm] = rs2
func SW(rs1 byte, rs2 byte, imm int32) uint32 {
	// imm[11:5] rs2 rs1 010 imm[4:0] 0100011
	return SType(rs1, rs2, imm, 0b010)
}

// x[rd] = sign-extended(Mem[rs1 + imm])
func LB(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 000 rd 0000011
	return IType(rd, rs1, imm, 0b000, 0b0000011)
}

// x[rd] = sign-extended(Mem[rs1 + imm])
func LH(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 001 rd 0000011
	return IType(rd, rs1, imm, 0b001, 0b0000011)
}

// x[rd] = Mem[rs1 + imm]
func LW(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 010 rd 0000011
	return IType(rd, rs1, imm, 0b010, 0b0000011)
}

// x[rd] = zero-extended(Mem[rs1 + imm])
func LBU(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 100 rd 0000011
	return IType(rd, rs1, imm, 0b100, 0b0000011)
}

// x[rd] = zero-extended(Mem[rs1 + imm])
func LHU(rd byte, rs1 byte, imm int32) uint32 {
	// imm[11:0] rs1 101 rd 0000011
	return IType(rd, rs1, imm, 0b101, 0b0000011)
}
