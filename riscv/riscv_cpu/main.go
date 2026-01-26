package main

import . "github.com/codeharik/riscv_cpu/system_interface"

type RVI32System struct {
	ram RAM_Device
	rom ROM_Device
	bus SystemInterface
}

func NewRVI32System() *RVI32System {
	sys := &RVI32System{}
	sys.ram = RAM_Device{}
	sys.rom = ROM_Device{}
	sys.bus = *NewSystemInterface(&sys.rom, &sys.ram)
	return sys
}

func main() {
	println("Hello, World!")
}
