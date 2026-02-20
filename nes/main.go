package main

import (
	"fmt"
	"log"
	"os"

	"github.com/codeharik/nes/src"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run . <rom.nes>")
		os.Exit(1)
	}

	// Load ROM
	cart, err := src.LoadROM(os.Args[1])
	if err != nil {
		log.Fatalf("Failed to load ROM: %v", err)
	}
	fmt.Printf("ROM loaded: PRG=%dKB CHR=%dKB Mapper=%d Mirror=%d\n",
		len(cart.PRG)/1024, len(cart.CHR)/1024, cart.Mapper, cart.Mirror)

	// Create CPU with simple memory map (mapper 0)
	mem := src.NewSimpleMemory(cart)
	cpu := src.NewCPU(mem)

	fmt.Printf("PC=0x%04X (reset vector)\n\n", cpu.PC)

	// Step through first 20 instructions, printing each one
	for i := 0; i < 20; i++ {
		cpu.PrintInstruction()
		cpu.Step()
	}
}
