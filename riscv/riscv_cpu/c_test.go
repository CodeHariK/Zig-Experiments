package riscv

import (
	"fmt"
	"os"
	"testing"

	. "riscv/system_interface"
)

func byteArrayToUint32Array(data []byte) []uint32 {
	result := []uint32{}
	for i := 0; i < len(data); i += 4 {
		var word uint32 = 0
		word |= uint32(data[i])
		if i+1 < len(data) {
			word |= uint32(data[i+1]) << 8
		}
		if i+2 < len(data) {
			word |= uint32(data[i+2]) << 16
		}
		if i+3 < len(data) {
			word |= uint32(data[i+3]) << 24
		}
		result = append(result, word)
	}
	return result
}

func Test_C_CODE(t *testing.T) {
	// Load and run a binary `test_code/build/main.bin` to ensure ROM binary load
	// and basic instruction fetch work as expected.
	data, err := os.ReadFile("test_code/build/main.bin")
	if err != nil {
		t.Fatalf("failed to read binary: %v", err)
	}

	sys := NewRVI32System()
	sys.rom.Load(byteArrayToUint32Array(data))

	// First instruction in binary (little-endian word at offset 0)
	expected := uint32(0)
	if len(data) >= 4 {
		expected = uint32(data[0]) | uint32(data[1])<<8 | uint32(data[2])<<16 | uint32(data[3])<<24
	}

	// Run one cycle so IF stage fetches the first instruction
	sys.Cycle()
	f := sys.IF.GetFetchValuesOut()
	if f.Instruction != expected {
		t.Fatalf("first fetched instruction = 0x%08X; want 0x%08X", f.Instruction, expected)
	}

	// Run a few full instruction cycles to make sure it executes without panic
	for i := 0; i < 140; i++ {
		sys.Cycle()
		if sys.State == TERMINATE {
			break
		}
	}

	v, _ := sys.bus.Read(0x20000000, MEMORY_WIDTH_WORD)
	fmt.Printf("Final value at 0x20000000 = 0x%08X\n", v)
	if v != 0x30040f00 {
		t.Fatalf("Final value at 0x20000000 = 0x%08X; want 0x30040f00", v)
	}

	// v, _ = sys.bus.Read(0x20000004, MEMORY_WIDTH_WORD)
	// fmt.Printf("Final value at 0x20000004 = 0x%08X\n", v)
	// if v != 42 {
	// 	t.Fatalf("Final value at 0x20000004 = 0x%08X; want 42", v)
	// }
}
