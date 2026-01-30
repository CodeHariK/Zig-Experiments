package riscv

import (
	"fmt"
	. "riscv/pipeline"
	. "riscv/system_interface"
	"testing"
)

var rv *RVI32System = NewRVI32System()

func TestROMLoadAndRead(t *testing.T) {

	fmt.Println("")

	var data []uint32 = []uint32{0xCAFEBABE, 0x8BADF00D, 0xC0DECAFE}
	rv.rom.Load(data)
	rv.rom.PrintRom()

	for i, want := range data {
		addr := 0x10000000 + uint32(i*4)
		v, err := rv.bus.Read(addr, MEMORY_WIDTH_WORD)
		if err != nil {
			t.Fatalf("error reading ROM at 0x%08X: %v", addr, err)
		}
		if uint32(v) != want {
			t.Fatalf("ROM[%d] = 0x%08X; want 0x%08X", i, uint32(v), want)
		}
	}
}

func TestRAMWrite(t *testing.T) {
	fmt.Println("")

	rv.bus.Write(0x20000000, 0x12345678, MEMORY_WIDTH_WORD)
	v, _ := rv.bus.Read(0x20000000, MEMORY_WIDTH_WORD)
	if v != 0x12345678 {
		t.Fatalf("RAM[0] = 0x%08X; want 0x12345678", v)
	}

	rv.bus.Write(0x20400000, 0x87654321, MEMORY_WIDTH_WORD)
	v, _ = rv.bus.Read(0x20400000, MEMORY_WIDTH_WORD)
	if v != 0x87654321 {
		t.Fatalf("RAM[0] = 0x%08X; want 0x87654321", v)
	}

}

type romTestCase struct {
	instruction     uint32
	expected        uint32
	destReg         *byte
	destRam         *uint32
	readWidth       MEMORY_WIDTH
	expectReadError bool
}

var ZERO_REG byte = 0
var MINUS_ONE_REG byte = 1
var ONE_REG byte = 2
var NEG_MAX_REG byte = 3
var RAM_START_REG byte = 8
var RAM_START_0_VAL uint32 = 0x20000000
var RAM_START_1_VAL uint32 = 0x20000001
var RAM_START_2_VAL uint32 = 0x20000002
var RAM_START_3_VAL uint32 = 0x20000003
var SRC_REG_15 byte = 15
var SRC_REG_15_VAL uint32 = 0x01020304
var SRC_REG_16 byte = 16
var SRC_REG_16_VAL uint32 = 0x02030405
var DEST_REG_20 byte = 20

// var DEST_REG_21 byte = 21
var MEM_ZERO_VALUE uint32 = 0x12345678
var MEM_ONE_VALUE uint32 = 0xF1F2F3F4

func TestInstruction(t *testing.T) {

	fmt.Println("")

	rv.regFile[1] = NewRUint32(0xffffffff)
	rv.regFile[2] = NewRUint32(0x00000001)
	rv.regFile[3] = NewRUint32(0x80000000)
	rv.regFile[8] = NewRUint32(0x20000000)
	rv.regFile[15] = NewRUint32(0x01020304)
	rv.regFile[16] = NewRUint32(0x02030405)

	testCases := []romTestCase{}

	testCases = append(testCases, ADDIS...)
	testCases = append(testCases, ADDSUB...)
	testCases = append(testCases, SLLIS...)
	testCases = append(testCases, SLTS...)
	testCases = append(testCases, LOGICALS...)
	testCases = append(testCases, STORES...)
	testCases = append(testCases, LOADS...)

	instructions := []uint32{}
	for _, tc := range testCases {
		instructions = append(instructions, tc.instruction)
	}

	rv.rom.Load(instructions)

	for i, tc := range testCases {

		// Reset ram
		rv.bus.Write(0x20000000, MEM_ZERO_VALUE, MEMORY_WIDTH_WORD)
		rv.bus.Write(0x20000004, MEM_ONE_VALUE, MEMORY_WIDTH_WORD)
		//

		// Each instruction needs 5 cycles (IF -> DE -> EX -> MA -> WB) in this pipeline
		for cycle := 0; cycle < 5; cycle++ {
			rv.Cycle()
		}
		if tc.destRam == nil {
			v := rv.regFile[*tc.destReg].GetN()
			if !tc.expectReadError && v != tc.expected {
				t.Fatalf("Test case %d: After instruction, R%02d => 0x%08X; want 0x%08X", i, *tc.destReg, v, tc.expected)
			}
		} else {
			v, err := rv.bus.Read(*tc.destRam, tc.readWidth)
			if tc.expectReadError {
				if err == nil {
					t.Fatalf("Test case %d: expected error reading RAM at 0x%08X; got 0x%08X", i, *tc.destRam, v)
				}
				continue
			}
			if err != nil {
				t.Fatalf("Test case %d: error reading RAM at 0x%08X: %v", i, *tc.destRam, err)
			}
			if uint32(v) != tc.expected {
				t.Fatalf("Test case %d: RAM[0x%08X] = 0x%08X; want 0x%08X", i, *tc.destRam, uint32(v), tc.expected)
			}
		}
	}

}

var ADDIS []romTestCase = []romTestCase{
	{
		ADDI(DEST_REG_20, SRC_REG_15, 2),
		SRC_REG_15_VAL + 2, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		ADDI(DEST_REG_20, SRC_REG_15, -1),
		SRC_REG_15_VAL - 1, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	// Zero immediate
	{
		ADDI(DEST_REG_20, SRC_REG_15, 0),
		SRC_REG_15_VAL, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	// rd = x0 (discard)
	{
		ADDI(ZERO_REG, SRC_REG_15, 123),
		0,
		&ZERO_REG,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	// Max positive 12-bit immediate
	{
		ADDI(DEST_REG_20, SRC_REG_15, 2047),
		SRC_REG_15_VAL + 2047,
		&DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	// Max negative 12-bit immediate (-2048)
	{
		ADDI(DEST_REG_20, SRC_REG_15, -2048),
		SRC_REG_15_VAL - 2048,
		&DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	// Wraparound: 0xFFFFFFFF + 1
	{
		ADDI(DEST_REG_20, MINUS_ONE_REG, 1),
		0x0,
		&DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
}

var ADDSUB []romTestCase = []romTestCase{
	{
		ADD(DEST_REG_20, SRC_REG_15, SRC_REG_16),
		SRC_REG_15_VAL + SRC_REG_16_VAL, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		ADD(DEST_REG_20, SRC_REG_15, ZERO_REG),
		SRC_REG_15_VAL, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		ADD(DEST_REG_20, MINUS_ONE_REG, ONE_REG),
		0x00000000, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		ADD(DEST_REG_20, ONE_REG, MINUS_ONE_REG),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		ADD(ZERO_REG, SRC_REG_15, SRC_REG_16),
		0, &ZERO_REG,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		ADD(DEST_REG_20, NEG_MAX_REG, NEG_MAX_REG),
		0x00000000, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SUB(DEST_REG_20, SRC_REG_15, SRC_REG_16),
		SRC_REG_15_VAL - SRC_REG_16_VAL, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SUB(DEST_REG_20, SRC_REG_15, ZERO_REG),
		SRC_REG_15_VAL, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SUB(DEST_REG_20, SRC_REG_15, SRC_REG_15),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SUB(DEST_REG_20, ZERO_REG, ONE_REG),
		0xFFFFFFFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
}

var SLLIS []romTestCase = []romTestCase{
	{
		SLL(DEST_REG_20, SRC_REG_15, ONE_REG),
		SRC_REG_15_VAL << 1, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLL(DEST_REG_20, SRC_REG_15, SRC_REG_16),
		SRC_REG_15_VAL << (SRC_REG_16_VAL & 0x1F), &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLL(DEST_REG_20, SRC_REG_15, ZERO_REG),
		SRC_REG_15_VAL, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLL(ZERO_REG, SRC_REG_15, ONE_REG),
		0, &ZERO_REG,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLLI(DEST_REG_20, SRC_REG_15, 2),
		SRC_REG_15_VAL << 2, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLLI(DEST_REG_20, ONE_REG, 31),
		uint32(1 << 31), &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLLI(DEST_REG_20, ONE_REG, 32), // encoded shamt = 0
		1, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},

	{
		SRL(DEST_REG_20, SRC_REG_15, SRC_REG_16),
		SRC_REG_15_VAL >> (SRC_REG_16_VAL & 0x1F), &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SRLI(DEST_REG_20, SRC_REG_15, 3),
		SRC_REG_15_VAL >> 3, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
}

var SLTS []romTestCase = []romTestCase{
	{
		SLT(DEST_REG_20, SRC_REG_15, SRC_REG_16),
		1, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLT(DEST_REG_20, MINUS_ONE_REG, ONE_REG),
		1, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLT(DEST_REG_20, ONE_REG, MINUS_ONE_REG),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLT(DEST_REG_20, SRC_REG_15, SRC_REG_15),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLTI(DEST_REG_20, MINUS_ONE_REG, 2),
		1, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLTI(DEST_REG_20, ONE_REG, -1),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLTU(DEST_REG_20, SRC_REG_15, SRC_REG_16),
		1, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLTU(DEST_REG_20, MINUS_ONE_REG, ONE_REG),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLTU(DEST_REG_20, ONE_REG, MINUS_ONE_REG),
		1, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLTIU(DEST_REG_20, MINUS_ONE_REG, 2),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLTIU(DEST_REG_20, ONE_REG, -1),
		1, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		SLTIU(DEST_REG_20, MINUS_ONE_REG, -1),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
}

var LOGICALS []romTestCase = []romTestCase{
	{
		XOR(DEST_REG_20, SRC_REG_15, SRC_REG_16),
		SRC_REG_15_VAL ^ SRC_REG_16_VAL, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		XORI(DEST_REG_20, SRC_REG_15, 3),
		SRC_REG_15_VAL ^ 3, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},

	{
		OR(DEST_REG_20, SRC_REG_15, SRC_REG_16),
		SRC_REG_15_VAL | SRC_REG_16_VAL, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		ORI(DEST_REG_20, SRC_REG_15, 3),
		SRC_REG_15_VAL | 3, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},

	{
		AND(DEST_REG_20, SRC_REG_15, SRC_REG_16),
		SRC_REG_15_VAL & SRC_REG_16_VAL, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		ANDI(DEST_REG_20, SRC_REG_15, 3),
		SRC_REG_15_VAL & 3, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
}

var STORES []romTestCase = []romTestCase{
	{
		SB(RAM_START_REG, ONE_REG, 0),
		1, nil,
		&RAM_START_0_VAL, MEMORY_WIDTH_BYTE, false,
	},
	{
		SB(RAM_START_REG, ONE_REG, 1),
		1, nil,
		&RAM_START_1_VAL, MEMORY_WIDTH_BYTE, false,
	},
	{
		SB(RAM_START_REG, ONE_REG, 2),
		1, nil,
		&RAM_START_2_VAL, MEMORY_WIDTH_BYTE, false,
	},
	{
		SB(RAM_START_REG, ONE_REG, 3),
		1, nil,
		&RAM_START_3_VAL, MEMORY_WIDTH_BYTE, false,
	},

	{
		SH(RAM_START_REG, SRC_REG_15, 0),
		SRC_REG_15_VAL & 0xFFFF, nil,
		&RAM_START_0_VAL, MEMORY_WIDTH_HALF, false,
	},
	{
		SH(RAM_START_REG, SRC_REG_15, 1),
		SRC_REG_15_VAL & 0xFFFF, nil,
		&RAM_START_1_VAL, MEMORY_WIDTH_HALF, true,
	},
	{
		SH(RAM_START_REG, SRC_REG_15, 2),
		SRC_REG_15_VAL & 0xFFFF, nil,
		&RAM_START_2_VAL, MEMORY_WIDTH_HALF, false,
	},
	{
		SH(RAM_START_REG, SRC_REG_15, 3),
		SRC_REG_15_VAL & 0xFFFF, nil,
		&RAM_START_3_VAL, MEMORY_WIDTH_HALF, true,
	},

	{
		SW(RAM_START_REG, SRC_REG_15, 0),
		SRC_REG_15_VAL, nil,
		&RAM_START_0_VAL, MEMORY_WIDTH_WORD, false,
	},
	{
		SW(RAM_START_REG, SRC_REG_15, 1),
		SRC_REG_15_VAL, nil,
		&RAM_START_1_VAL, MEMORY_WIDTH_WORD, true,
	},
	{
		SW(RAM_START_REG, SRC_REG_15, 2),
		SRC_REG_15_VAL, nil,
		&RAM_START_2_VAL, MEMORY_WIDTH_WORD, true,
	},
	{
		SW(RAM_START_REG, SRC_REG_15, 3),
		SRC_REG_15_VAL, nil,
		&RAM_START_3_VAL, MEMORY_WIDTH_WORD, true,
	},
}

var LOADS []romTestCase = []romTestCase{
	{
		LB(DEST_REG_20, RAM_START_REG, 0),
		(MEM_ZERO_VALUE >> 24) & 0xFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		LB(DEST_REG_20, RAM_START_REG, 1),
		(MEM_ZERO_VALUE >> 16) & 0xFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		LB(DEST_REG_20, RAM_START_REG, 2),
		(MEM_ZERO_VALUE >> 8) & 0xFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		LB(DEST_REG_20, RAM_START_REG, 3),
		MEM_ZERO_VALUE & 0xFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},

	{
		LBU(DEST_REG_20, RAM_START_REG, 4),
		(MEM_ONE_VALUE >> 24) & 0xFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		LBU(DEST_REG_20, RAM_START_REG, 5),
		(MEM_ONE_VALUE >> 16) & 0xFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		LBU(DEST_REG_20, RAM_START_REG, 6),
		(MEM_ONE_VALUE >> 8) & 0xFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
	{
		LBU(DEST_REG_20, RAM_START_REG, 7),
		MEM_ONE_VALUE & 0xFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},

	{
		LH(DEST_REG_20, RAM_START_REG, 0),
		(MEM_ZERO_VALUE >> 16) & 0xFFFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_HALF, false,
	},
	{
		LH(DEST_REG_20, RAM_START_REG, 1),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_HALF, true,
	},
	{
		LH(DEST_REG_20, RAM_START_REG, 2),
		MEM_ZERO_VALUE & 0xFFFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_HALF, false,
	},
	{
		LH(DEST_REG_20, RAM_START_REG, 3),
		0, &DEST_REG_20,
		nil, MEMORY_WIDTH_HALF, true,
	},

	{
		LHU(DEST_REG_20, RAM_START_REG, 4),
		(MEM_ONE_VALUE >> 16) & 0xFFFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_HALF, false,
	},
	{
		LHU(DEST_REG_20, RAM_START_REG, 6),
		MEM_ONE_VALUE & 0xFFFF, &DEST_REG_20,
		nil, MEMORY_WIDTH_HALF, false,
	},

	{
		LW(DEST_REG_20, RAM_START_REG, 0),
		MEM_ZERO_VALUE, &DEST_REG_20,
		nil, MEMORY_WIDTH_WORD, false,
	},
	{
		LW(DEST_REG_20, RAM_START_REG, 1),
		MEM_ZERO_VALUE, &DEST_REG_20,
		nil, MEMORY_WIDTH_WORD, true,
	},
	{
		LW(DEST_REG_20, RAM_START_REG, 2),
		MEM_ZERO_VALUE, &DEST_REG_20,
		nil, MEMORY_WIDTH_WORD, true,
	},
	{
		LW(DEST_REG_20, RAM_START_REG, 3),
		MEM_ZERO_VALUE, &DEST_REG_20,
		nil, MEMORY_WIDTH_WORD, true,
	},

	{
		LUI(DEST_REG_20, int32(MEM_ONE_VALUE&0xFFFFF000)>>12),
		(MEM_ONE_VALUE & 0xFFFFF000), &DEST_REG_20,
		nil, MEMORY_WIDTH_WORD, false,
	},
	{
		ADDI(DEST_REG_20, DEST_REG_20, int32(MEM_ONE_VALUE)&0x00000FFF),
		MEM_ONE_VALUE, &DEST_REG_20,
		nil, MEMORY_WIDTH_BYTE, false,
	},
}
