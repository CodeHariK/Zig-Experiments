package pipeline

type PipelineStage interface {
	readyToSend() bool
	readyToReceive() bool

	compute()
	latchNext()
}
