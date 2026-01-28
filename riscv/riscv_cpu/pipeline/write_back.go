package pipeline

import . "riscv/system_interface"

type WriteBackParams struct {
	regFile                 *[32]RUint32
	shouldStall             func() bool
	getMemoryAccessValuesIn func() ExecutedValues
}

func NewWriteBackParams(regFile *[32]RUint32, shouldStall func() bool, getMemoryAccessValuesIn func() ExecutedValues) *WriteBackParams {
	return &WriteBackParams{
		regFile:                 regFile,
		shouldStall:             shouldStall,
		getMemoryAccessValuesIn: getMemoryAccessValuesIn,
	}
}

type WriteBackStage struct {
	regFile                 *[32]RUint32
	shouldStall             func() bool
	getMemoryAccessValuesIn func() ExecutedValues
}

func NewWriteBackStage(params *WriteBackParams) *WriteBackStage {

	ma := &WriteBackStage{}

	ma.regFile = params.regFile
	ma.shouldStall = params.shouldStall
	ma.getMemoryAccessValuesIn = params.getMemoryAccessValuesIn
	return ma
}

func (ma *WriteBackStage) Compute() {
	if !ma.shouldStall() {
		memoryAccessValues := ma.getMemoryAccessValuesIn()
		if memoryAccessValues.isAluOperation {
			// Write-back to register file (x0 is hardwired zero)
			if ma.regFile != nil && memoryAccessValues.rd != 0 {
				ma.regFile[memoryAccessValues.rd].SetN(memoryAccessValues.aluResult)
			}
		}
	}
}

func (ma *WriteBackStage) LatchNext() {
}
