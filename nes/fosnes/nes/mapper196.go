package nes

import "encoding/gob"

// Mapper196 is an MMC3 variant used by bootleg/pirate games (e.g. Super Mario 14).
// The only difference from standard MMC3 is that write addresses in the $8000-$FFFF
// range are scrambled: bit 0 is replaced by bit 2.
type Mapper196 struct {
	inner *Mapper4
}

func NewMapper196(console *Console, cartridge *Cartridge) Mapper {
	m4 := NewMapper4(console, cartridge).(*Mapper4)
	return &Mapper196{inner: m4}
}

func (m *Mapper196) Read(address uint16) byte {
	return m.inner.Read(address)
}

func (m *Mapper196) Write(address uint16, value byte) {
	if address >= 0x8000 {
		address = (address & 0xE000) | ((address & 0x04) >> 2)
	}
	m.inner.Write(address, value)
}

func (m *Mapper196) Step() {
	m.inner.Step()
}

func (m *Mapper196) Save(encoder *gob.Encoder) error {
	return m.inner.Save(encoder)
}

func (m *Mapper196) Load(decoder *gob.Decoder) error {
	return m.inner.Load(decoder)
}
