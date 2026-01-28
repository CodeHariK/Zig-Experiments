package systeminterface

type Register32 struct {
	value     uint32
	valueNext uint32
}

func NewRegister32(value uint32) Register32 {
	return Register32{value: value, valueNext: value}
}

func (r *Register32) Get() uint32 {
	return r.value
}

func (r *Register32) GetN() uint32 {
	return r.valueNext
}

func (r *Register32) SetN(value uint32) {
	r.valueNext = value
}

func (r *Register32) LatchNext() {
	r.value = r.valueNext
}
