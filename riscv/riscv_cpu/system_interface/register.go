package systeminterface

type RUint32 struct {
	value     uint32
	valueNext uint32
}

func NewRUint32(value uint32) RUint32 {
	return RUint32{value: value, valueNext: value}
}

func (r *RUint32) Get() uint32 {
	return r.value
}

func (r *RUint32) GetN() uint32 {
	return r.valueNext
}

func (r *RUint32) SetN(value uint32) {
	r.valueNext = value
}

func (r *RUint32) LatchNext() {
	r.value = r.valueNext
}

//  -----------------

type RInt32 struct {
	value     int32
	valueNext int32
}

func NewRInt32(value int32) RInt32 {
	return RInt32{value: value, valueNext: value}
}

func (r *RInt32) Get() int32 {
	return r.value
}

func (r *RInt32) GetN() int32 {
	return r.valueNext
}

func (r *RInt32) SetN(value int32) {
	r.valueNext = value
}

func (r *RInt32) LatchNext() {
	r.value = r.valueNext
}

//  -----------------

type RByte struct {
	value     byte
	valueNext byte
}

func NewRByte(value byte) RByte {
	return RByte{value: value, valueNext: value}
}

func (r *RByte) Get() byte {
	return r.value
}

func (r *RByte) GetN() byte {
	return r.valueNext
}

func (r *RByte) SetN(value byte) {
	r.valueNext = value
}

func (r *RByte) LatchNext() {
	r.value = r.valueNext
}
