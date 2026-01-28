package main

import (
	. "riscv/system_interface"
	"testing"
)

var rv *RVI32System = NewRVI32System()

var data []uint32 = []uint32{0xCAFEBABE, 0x8BADF00D, 0xC0DECAFE}

func init() {
	rv.rom.Load(data)

	rv.rom.PrintRom()

}

func TestROMLoadAndRead(t *testing.T) {

	for i, want := range data {
		addr := 0x10000000 + uint64(i*4)
		v, err := rv.bus.Read(addr)
		if err != nil {
			t.Fatalf("error reading ROM at 0x%X: %v", addr, err)
		}
		if uint32(v) != want {
			t.Fatalf("ROM[%d] = 0x%X; want 0x%X", i, uint32(v), want)
		}
	}
}

func TestRAMWrite(t *testing.T) {
	rv.bus.Write(0x20000000, 0x12345678)
	v, _ := rv.bus.Read(0x20000000)
	if v != 0x12345678 {
		t.Fatalf("RAM[0] = 0x%X; want 0x12345678", v)
	}

	rv.bus.Write(0x20400000, 0x87654321)
	v, _ = rv.bus.Read(0x20000000)
	if v != 0x87654321 {
		t.Fatalf("RAM[0] = 0x%X; want 0x87654321", v)
	}

}

type romTestCase struct {
	instruction uint32
	expected    uint32
}

func TestInstruction(t *testing.T) {
	rv.regFile[1] = NewRegister32(0x01020304)
	rv.regFile[2] = NewRegister32(0x02030405)
	rv.regFile[5] = NewRegister32(0x00000001)

	testCases := []romTestCase{
		{
			// imm[11:0] rs1 000 rd 0010011 ADDI => x[rd] = x[rs1] + sign-extended(immediate)
			0b000000000001_00001_000_00011_0010011, // ADDI x3, x1, 1 => x3 = x1 + 1
			0x01020305,
		},
		{
			// imm[11:0] rs1 000 rd 0010011 ADDI => x[rd] = x[rs1] + sign-extended(immediate)
			0b111111111111_00001_000_00011_0010011, // ADDI x3, x1, 1 => x3 = x1 - 1
			0x01020303,
		},

		{
			// 0000000 rs2 rs1 000 rd 0110011 ADD => x[rd] = x[rs1] + x[rs2]
			0b0000000_00001_00010_000_00011_0110011, // ADD x3, x1, x2 => x3 = x1 + x2
			0x03050709,
		},
		{
			// 0100000 rs2 rs1 000 rd 0110011 SUB => x[rd] = x[rs1] - x[rs2]
			0b0100000_00010_00001_000_00011_0110011, // SUB x3, x1, x2 => x3 = x1 - x2 (rs2=00010, rs1=00001)
			0xFEFEFEFF,
		},

		{
			// 0000000 rs2 rs1 001 rd 0110011 SLL => x[rd] = x[rs1] << (x[rs2] & 0x1F)
			0b0000000_00101_00001_001_00011_0110011, // SLL x3, x1, x5 => x3 = x1 << (x5 & 0x1F)
			0x01020304 << 1,
		},
		{
			// 0000000 shamt rs1 001 rd 0010011 SLLI => x[rd] = x[rs1] << shamt
			0b0000000_00011_00001_001_00011_0010011, // SLLI x3, x1, 1 => x3 = x1 << 3
			0x01020304 << 3,
		},

		{
			// 0000000 rs2 rs1 010 rd 0110011 SLT => x[rd] = (int32(x[rs1]) < int32(x[rs2])) ? 1 : 0
			0b0000000_00010_00001_010_00011_0110011, // SLT x3, x1, x2 => x3 = (int32(x1) < int32(x2)) ? 1 : 0
			1,
		},
		{
			// imm[11:0] rs1 010 rd 0010011 SLTI => x[rd] = (int32(x[rs1]) < sign-extended(immediate)) ? 1 : 0
			0b000000000010_00001_010_00011_0010011, // SLTI x3, x1, 2 => x3 = (int32(x1) < 2) ? 1 : 0
			0,
		},

		{
			// 0000000 rs2 rs1 011 rd 0110011 SLTU => x[rd] = (x[rs1] < x[rs2]) ? 1 : 0
			0b0000000_00101_00001_011_00011_0110011, // SLTU x3, x1, x5 => x3 = (x1 < x5) ? 1 : 0
			0,
		},
		{
			// imm[11:0] rs1 011 rd 0010011 SLTIU => x[rd] = (x[rs1] < zero-extended(immediate)) ? 1 : 0
			0b000000000001_00001_011_00011_0010011, // SLTIU x3, x1, 1 => x3 = (x1 < 1) ? 1 : 0
			0,
		},

		{
			// 0000000 rs2 rs1 100 rd 0110011 XOR => x[rd] = x[rs1] ^ x[rs2]
			0b0000000_00010_00001_100_00011_0110011, // XOR x3, x1, x2 => x3 = x1 ^ x2
			0x01020304 ^ 0x02030405,
		},
		{
			// imm[11:0] rs1 100 rd 0010011 XORI => x[rd] = x[rs1] ^ sign-extended(immediate)
			0b000000000011_00001_100_00011_0010011, // XORI x3, x1, 3 => x3 = x1 ^ 3
			0x01020304 ^ 3,
		},

		{
			// 0000000 rs2 rs1 101 rd 0110011 SRL => x[rd] = x[rs1] >> (x[rs2] & 0x1F)
			0b0000000_00101_00001_101_00011_0110011, // SRL x3, x1, x5 => x3 = x1 >> (x5 & 0x1F)
			0x01020304 >> 1,
		},
		{
			// 0000000 shamt rs1 101 rd 0010011 SRLI => x[rd] = x[rs1] >> shamt
			0b0000000_00011_00001_101_00011_0010011, // SRLI x3, x1, 3 => x3 = x1 >> 3
			0x01020304 >> 3,
		},

		{
			// 0000000 rs2 rs1 110 rd 0110011 OR => x[rd] = x[rs1] | x[rs2]
			0b0000000_00010_00001_110_00011_0110011, // OR x3, x1, x2 => x3 = x1 | x2
			0x01020304 | 0x02030405,
		},
		{
			// imm[11:0] rs1 110 rd 0010011 ORI => x[rd] = x[rs1] | sign-extended(immediate)
			0b000000000011_00001_110_00011_0010011, // ORI x3, x1, 3 => x3 = x1 | 3
			0x01020304 | 3,
		},

		{
			// 0000000 rs2 rs1 111 rd 0110011 AND => x[rd] = x[rs1] & x[rs2]
			0b0000000_00010_00001_111_00011_0110011, // AND x3, x1, x2 => x3 = x1 & x2
			0x01020304 & 0x02030405,
		},
		{
			// imm[11:0] rs1 111 rd 0010011 ANDI => x[rd] = x[rs1] & sign-extended(immediate)
			0b000000001111_00001_111_00011_0010011, // ANDI x3, x1, 15 => x3 = x1 & 15
			0x01020304 & 15,
		},
	}

	instructions := []uint32{}
	for _, tc := range testCases {
		instructions = append(instructions, tc.instruction)
	}

	rv.rom.Load(instructions)

	for i, tc := range testCases {
		// Each instruction needs 5 cycles (IF -> DE -> EX -> MA -> WB) in this pipeline
		for cycle := 0; cycle < 5; cycle++ {
			rv.Cycle()
		}
		v := rv.regFile[3].GetN()
		if v != tc.expected {
			t.Fatalf("Test case %d: After instruction, x3 = 0x%X; want 0x%X", i, v, tc.expected)
		}
	}

}
