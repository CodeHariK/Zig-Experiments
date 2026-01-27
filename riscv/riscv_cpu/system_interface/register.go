package systeminterface

type Register32 struct {
	Value uint32
}

func NewRegister32(value uint32) *Register32 {
	return &Register32{Value: value}
}

func (r *Register32) Get() uint32 {
	return r.Value
}

func (r *Register32) Set(value uint32) {
	r.Value = value
}
