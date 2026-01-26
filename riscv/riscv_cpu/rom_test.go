package main

import (
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

}
