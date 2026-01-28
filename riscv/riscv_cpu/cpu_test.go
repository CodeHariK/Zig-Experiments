package riscv

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
		addr := 0x10000000 + uint32(i*4)
		v, err := rv.bus.Read(addr, MEMORY_WIDTH_WORD)
		if err != nil {
			t.Fatalf("error reading ROM at 0x%X: %v", addr, err)
		}
		if uint32(v) != want {
			t.Fatalf("ROM[%d] = 0x%X; want 0x%X", i, uint32(v), want)
		}
	}
}

func TestRAMWrite(t *testing.T) {
	rv.bus.Write(0x20000000, 0x12345678, MEMORY_WIDTH_WORD)
	v, _ := rv.bus.Read(0x20000000, MEMORY_WIDTH_WORD)
	if v != 0x12345678 {
		t.Fatalf("RAM[0] = 0x%X; want 0x12345678", v)
	}

	rv.bus.Write(0x20400000, 0x87654321, MEMORY_WIDTH_WORD)
	v, _ = rv.bus.Read(0x20400000, MEMORY_WIDTH_WORD)
	if v != 0x87654321 {
		t.Fatalf("RAM[0] = 0x%X; want 0x87654321", v)
	}

}

type romTestCase struct {
	instruction     uint32
	expected        uint32
	read            *uint32
	readWidth       MEMORY_WIDTH
	expectReadError bool
}

func TestInstruction(t *testing.T) {
	rv.regFile[1] = NewRUint32(0x01020304)
	rv.regFile[2] = NewRUint32(0x02030405)
	rv.regFile[5] = NewRUint32(0x00000001)
	rv.regFile[6] = NewRUint32(0x20000000)

	ramTestStoreLocation0 := uint32(0x20000000)
	ramTestStoreLocation2 := uint32(0x20000000 + 2)
	ramTestStoreLocation3 := uint32(0x20000000 + 3)

	testCases := []romTestCase{
		{
			// imm[11:0] rs1 000 rd 0010011 ADDI => x[rd] = x[rs1] + sign-extended(immediate)
			0b000000000001_00001_000_00011_0010011, // ADDI x3, x1, 1 => x3 = x1 + 1
			0x01020305,
			nil, MEMORY_WIDTH_BYTE, false,
		},
		{
			// imm[11:0] rs1 000 rd 0010011 ADDI => x[rd] = x[rs1] + sign-extended(immediate)
			0b111111111111_00001_000_00011_0010011, // ADDI x3, x1, 1 => x3 = x1 - 1
			0x01020303,
			nil, MEMORY_WIDTH_BYTE, false,
		},

		{
			// 0000000 rs2 rs1 000 rd 0110011 ADD => x[rd] = x[rs1] + x[rs2]
			0b0000000_00001_00010_000_00011_0110011, // ADD x3, x1, x2 => x3 = x1 + x2
			0x03050709,
			nil, MEMORY_WIDTH_BYTE, false,
		},
		{
			// 0100000 rs2 rs1 000 rd 0110011 SUB => x[rd] = x[rs1] - x[rs2]
			0b0100000_00010_00001_000_00011_0110011, // SUB x3, x1, x2 => x3 = x1 - x2 (rs2=00010, rs1=00001)
			0xFEFEFEFF,
			nil, MEMORY_WIDTH_BYTE, false,
		},

		{
			// 0000000 rs2 rs1 001 rd 0110011 SLL => x[rd] = x[rs1] << (x[rs2] & 0x1F)
			0b0000000_00101_00001_001_00011_0110011, // SLL x3, x1, x5 => x3 = x1 << (x5 & 0x1F)
			0x01020304 << 1,
			nil, MEMORY_WIDTH_BYTE, false,
		},
		{
			// 0000000 shamt rs1 001 rd 0010011 SLLI => x[rd] = x[rs1] << shamt
			0b0000000_00011_00001_001_00011_0010011, // SLLI x3, x1, 1 => x3 = x1 << 3
			0x01020304 << 3,
			nil, MEMORY_WIDTH_BYTE, false,
		},

		{
			// 0000000 rs2 rs1 010 rd 0110011 SLT => x[rd] = (int32(x[rs1]) < int32(x[rs2])) ? 1 : 0
			0b0000000_00010_00001_010_00011_0110011, // SLT x3, x1, x2 => x3 = (int32(x1) < int32(x2)) ? 1 : 0
			1,
			nil, MEMORY_WIDTH_BYTE, false,
		},
		{
			// imm[11:0] rs1 010 rd 0010011 SLTI => x[rd] = (int32(x[rs1]) < sign-extended(immediate)) ? 1 : 0
			0b000000000010_00001_010_00011_0010011, // SLTI x3, x1, 2 => x3 = (int32(x1) < 2) ? 1 : 0
			0,
			nil, MEMORY_WIDTH_BYTE, false,
		},

		{
			// 0000000 rs2 rs1 011 rd 0110011 SLTU => x[rd] = (x[rs1] < x[rs2]) ? 1 : 0
			0b0000000_00101_00001_011_00011_0110011, // SLTU x3, x1, x5 => x3 = (x1 < x5) ? 1 : 0
			0,
			nil, MEMORY_WIDTH_BYTE, false,
		},
		{
			// imm[11:0] rs1 011 rd 0010011 SLTIU => x[rd] = (x[rs1] < zero-extended(immediate)) ? 1 : 0
			0b000000000001_00001_011_00011_0010011, // SLTIU x3, x1, 1 => x3 = (x1 < 1) ? 1 : 0
			0,
			nil, MEMORY_WIDTH_BYTE, false,
		},

		{
			// 0000000 rs2 rs1 100 rd 0110011 XOR => x[rd] = x[rs1] ^ x[rs2]
			instruction: 0b0000000_00010_00001_100_00011_0110011, // XOR x3, x1, x2 => x3 = x1 ^ x2
			expected:    0x01020304 ^ 0x02030405,
			read:        nil, readWidth: MEMORY_WIDTH_BYTE,
		},
		{
			// imm[11:0] rs1 100 rd 0010011 XORI => x[rd] = x[rs1] ^ sign-extended(immediate)
			0b000000000011_00001_100_00011_0010011, // XORI x3, x1, 3 => x3 = x1 ^ 3
			0x01020304 ^ 3,
			nil, MEMORY_WIDTH_BYTE, false,
		},

		{
			// 0000000 rs2 rs1 101 rd 0110011 SRL => x[rd] = x[rs1] >> (x[rs2] & 0x1F)
			0b0000000_00101_00001_101_00011_0110011, // SRL x3, x1, x5 => x3 = x1 >> (x5 & 0x1F)
			0x01020304 >> 1,
			nil, MEMORY_WIDTH_BYTE, false,
		},
		{
			// 0000000 shamt rs1 101 rd 0010011 SRLI => x[rd] = x[rs1] >> shamt
			0b0000000_00011_00001_101_00011_0010011, // SRLI x3, x1, 3 => x3 = x1 >> 3
			0x01020304 >> 3,
			nil, MEMORY_WIDTH_BYTE, false,
		},

		{
			// 0000000 rs2 rs1 110 rd 0110011 OR => x[rd] = x[rs1] | x[rs2]
			0b0000000_00010_00001_110_00011_0110011, // OR x3, x1, x2 => x3 = x1 | x2
			0x01020304 | 0x02030405,
			nil, MEMORY_WIDTH_BYTE, false,
		},
		{
			// imm[11:0] rs1 110 rd 0010011 ORI => x[rd] = x[rs1] | sign-extended(immediate)
			0b000000000011_00001_110_00011_0010011, // ORI x3, x1, 3 => x3 = x1 | 3
			0x01020304 | 3,
			nil, MEMORY_WIDTH_BYTE, false,
		},

		{
			// 0000000 rs2 rs1 111 rd 0110011 AND => x[rd] = x[rs1] & x[rs2]
			0b0000000_00010_00001_111_00011_0110011, // AND x3, x1, x2 => x3 = x1 & x2
			0x01020304 & 0x02030405,
			nil, MEMORY_WIDTH_BYTE, false,
		},
		{
			// imm[11:0] rs1 111 rd 0010011 ANDI => x[rd] = x[rs1] & sign-extended(immediate)
			0b000000001111_00001_111_00011_0010011, // ANDI x3, x1, 15 => x3 = x1 & 15
			0x01020304 & 15,
			nil, MEMORY_WIDTH_BYTE, false,
		},

		{
			// imm[11:5] rs2 rs1 000 imm[4:0] 0100011 SB => M[rs1 + imm] = rs2
			0b0000000_00010_00110_000_00011_0100011, // M[x6 + 3] = x2
			0x05,                                    // expect lowest byte of x2
			&ramTestStoreLocation3, MEMORY_WIDTH_BYTE, false,
		},
		{
			// imm[11:5] rs2 rs1 001 imm[4:0] 0100011 SH => M[rs1 + imm] = rs2
			0b0000000_00010_00110_001_00010_0100011, // M[x6 + 2] = x2
			0x0405,                                  // expect lowest 2 bytes of x2
			&ramTestStoreLocation2, MEMORY_WIDTH_HALF, false,
		},
		{
			// imm[11:5] rs2 rs1 010 imm[4:0] 0100011 SW => M[rs1 + imm] = rs2
			0b0000000_00010_00110_010_00000_0100011, // M[x6 + 0] = x2
			0x02030405,                              // expect lowest 2 bytes of x2
			&ramTestStoreLocation0, MEMORY_WIDTH_WORD, false,
		},
		{
			// imm[11:5] rs2 rs1 001 imm[4:0] 0100011 SH (misaligned) => M[x6 + 3] = x2 (misaligned)
			0b0000000_00010_00110_001_00011_0100011, // M[x6 + 3] = x2 (misaligned halfword)
			0x0,
			&ramTestStoreLocation3, MEMORY_WIDTH_HALF, true,
		},
		{
			// imm[11:5] rs2 rs1 010 imm[4:0] 0100011 SW (misaligned) => M[x6 + 3] = x2 (misaligned)
			0b0000000_00010_00110_010_00011_0100011, // M[x6 + 3] = x2 (misaligned word)
			0x0,
			&ramTestStoreLocation3, MEMORY_WIDTH_WORD, true,
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
		if tc.read == nil {
			v := rv.regFile[3].GetN()
			if v != tc.expected {
				t.Fatalf("Test case %d: After instruction, x3 = 0x%X; want 0x%X", i, v, tc.expected)
			}
		} else {
			v, err := rv.bus.Read(*tc.read, tc.readWidth)
			if tc.expectReadError {
				if err == nil {
					t.Fatalf("Test case %d: expected error reading RAM at 0x%X; got 0x%X", i, *tc.read, v)
				}
				continue
			}
			if err != nil {
				t.Fatalf("Test case %d: error reading RAM at 0x%X: %v", i, *tc.read, err)
			}
			if uint32(v) != tc.expected {
				t.Fatalf("Test case %d: RAM[0x%X] = 0x%X; want 0x%X", i, *tc.read, uint32(v), tc.expected)
			}
		}
	}

}
