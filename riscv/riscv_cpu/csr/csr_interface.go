package csr

import (
	. "riscv/system_interface"
)

type CSRInterface struct {
	Cycles  RInt64
	Instret RInt64 // Instructions Retired
}

func NewCSRInterface() *CSRInterface {
	return &CSRInterface{}
}

func (ci *CSRInterface) Read(addr uint32) uint32 {
	// isReadOnly := addr >> 10
	permission := (addr >> 8) & 0b11

	if permission != 0 {
		// For simplicity, we only implement user-level CSRs (permission == 0)
		panic("CSR read: Unsupported permission level")
	}

	switch addr {
	case 0xC00:
		return uint32(ci.Cycles.GetValueLow())
	case 0xC01:
		return uint32(ci.Cycles.GetValueLow())
	case 0xC02:
		return uint32(ci.Instret.GetValueLow())

	case 0xC80:
		return uint32(ci.Cycles.GetValueHigh())
	case 0xC81:
		return uint32(ci.Cycles.GetValueHigh())
	case 0xC82:
		return uint32(ci.Instret.GetValueHigh())

	}

	return 0
}

func (ci *CSRInterface) Write(addr uint32, value uint32) {
	isReadOnly := addr >> 10
	permission := (addr >> 8) & 0b11

	if permission != 0 {
		// For simplicity, we only implement user-level CSRs (permission == 0)
		panic("CSR read: Unsupported permission level")
	}

	if isReadOnly != 0 {
		// Attempt to write to a read-only CSR
		panic("CSR write: Attempt to write to read-only CSR")
	}

}

func (ci *CSRInterface) Compute() {
	ci.Cycles.SetN(ci.Cycles.GetN() + 1) // Increment cycle count every cycle
}

func (ci *CSRInterface) LatchNext() {
	ci.Cycles.LatchNext()
	ci.Instret.LatchNext()
}
