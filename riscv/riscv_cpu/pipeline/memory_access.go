package pipeline

type ExecutedValues struct {
	aluResult      uint32
	rd             byte
	isAluOperation bool
}

type MemoryAccessParams struct {
	shouldStall          func() bool
	getExecutionValuesIn func() ExecutedValues
}

func NewMemoryAccessParams(shouldStall func() bool, getExecutionValuesIn func() ExecutedValues) *MemoryAccessParams {
	return &MemoryAccessParams{
		shouldStall:          shouldStall,
		getExecutionValuesIn: getExecutionValuesIn,
	}
}

type MemoryAccessStage struct {
	shouldStall          func() bool
	getExecutionValuesIn func() ExecutedValues

	aluResult          uint32
	aluResultNext      uint32
	rd                 byte
	rdNext             byte
	isAluOperation     bool
	isAluOperationNext bool
}

func NewMemoryAccessStage(params *MemoryAccessParams) *MemoryAccessStage {

	ma := &MemoryAccessStage{}

	ma.shouldStall = params.shouldStall
	ma.getExecutionValuesIn = params.getExecutionValuesIn

	ma.aluResult = 0
	ma.aluResultNext = 0
	ma.rd = 0
	ma.rdNext = 0
	ma.isAluOperation = false
	ma.isAluOperationNext = false

	return ma
}

func (ma *MemoryAccessStage) Compute() {
	if !ma.shouldStall() {
		executedValues := ma.getExecutionValuesIn()
		ma.aluResultNext = executedValues.aluResult
		ma.rdNext = executedValues.rd
		ma.isAluOperationNext = executedValues.isAluOperation
	}
}

func (ma *MemoryAccessStage) LatchNext() {
	ma.aluResult = ma.aluResultNext
	ma.rd = ma.rdNext
	ma.isAluOperation = ma.isAluOperationNext
}

func (ma *MemoryAccessStage) GetMemoryAccessValuesOut() ExecutedValues {
	return ExecutedValues{
		aluResult:      ma.aluResult,
		rd:             ma.rd,
		isAluOperation: ma.isAluOperation,
	}
}
