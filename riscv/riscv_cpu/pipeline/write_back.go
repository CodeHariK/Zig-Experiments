package pipeline

import (
	"fmt"
	. "riscv/system_interface"
)

type WriteBackParams struct {
	regFile                 *[32]RUint32
	shouldStall             func() bool
	getMemoryAccessValuesIn func() MemoryAccessValues
}

func NewWriteBackParams(regFile *[32]RUint32, shouldStall func() bool, getMemoryAccessValuesIn func() MemoryAccessValues) *WriteBackParams {
	return &WriteBackParams{
		regFile:                 regFile,
		shouldStall:             shouldStall,
		getMemoryAccessValuesIn: getMemoryAccessValuesIn,
	}
}

type WriteBackStage struct {
	regFile                 *[32]RUint32
	shouldStall             func() bool
	getMemoryAccessValuesIn func() MemoryAccessValues
}

func NewWriteBackStage(params *WriteBackParams) *WriteBackStage {

	wb := &WriteBackStage{}

	wb.regFile = params.regFile
	wb.shouldStall = params.shouldStall
	wb.getMemoryAccessValuesIn = params.getMemoryAccessValuesIn
	return wb
}

func (wb *WriteBackStage) Compute() {
	if !wb.shouldStall() {
		// fmt.Println("@ WRITE_BACK")

		mv := wb.getMemoryAccessValuesIn()

		if mv.writeBackValid {

			// Write-back to register file (x0 is hardwired zero)
			if wb.regFile != nil && mv.rd != 0 {
				wb.regFile[mv.rd].SetN(mv.writeBackValue)
				fmt.Println()
			} else {
				fmt.Print(" (discarded)\n")
			}
		}
	}
}

func (wb *WriteBackStage) LatchNext() {
}
