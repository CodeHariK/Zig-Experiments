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

func TestInstruction(t *testing.T) {
	rv.regFile[1] = Register32{Value: 0x01020304}
	rv.regFile[2] = Register32{Value: 0x02030405}

	rv.rom.Load([]uint32{

		// imm[11:0] rs1 000 rd 0010011 ADDI => x[rd] = x[rs1] + sign-extended(immediate)
		0b000000000001_00001_000_00011_0010011, // ADDI x3, x1, 1 => x3 = x1 + 1

		// 0000000 rs2 rs1 000 rd 0110011 ADD => x[rd] = x[rs1] + x[rs2]
		0b0000000_00001_00010_000_00011_0110011, // ADD x3, x1, x2 => x3 = x1 + x2

		// 0100000 rs2 rs1 000 rd 0110011 SUB => x[rd] = x[rs1] - x[rs2]
		0b0100000_00010_00001_000_00011_0110011, // SUB x3, x1, x2 => x3 = x1 - x2 (rs2=00010, rs1=00001)
	})

	// Each instruction needs 3 cycles (IF -> DE -> EX) in this simple pipeline
	for i := 0; i < 3; i++ { rv.Cycle() }
	v := rv.regFile[3].Value
	if v != 0x01020305 {
		t.Fatalf("After ADDI, x3 = 0x%X; want 0x01020305", v)
	}

	for i := 0; i < 3; i++ { rv.Cycle() }
	v = rv.regFile[3].Value
	if v != 0x03050709 {
		t.Fatalf("After ADD, x3 = 0x%X; want 0x03050709", v)
	}

	for i := 0; i < 3; i++ { rv.Cycle() }
	v = rv.regFile[3].Value
	if v != 0xFEFEFEFF {
		t.Fatalf("After SUB, x3 = 0x%X; want 0xFEFEFEFF", v)
	}
}
