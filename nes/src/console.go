package src

import (
	"encoding/gob"
	"image"
	"image/color"
	"os"
	"path"
)

// Console is the overarching hardware structure. It orchestrates the CPU and PPU
// and ensures they are clocked at the correct 1:3 ratio.
type Console struct {
	CPU         *CPU
	PPU         *PPU
	APU         *APU
	Cartridge   *Cartridge
	Controller1 *Controller
	Controller2 *Controller
	Mapper      Mapper
	RAM         []byte
}

// NewConsole creates a unified NES console from a ROM cartridge path.
func NewConsole(path string) (*Console, error) {
	// 1. Parse and load the .nes file
	cartridge, err := LoadROM(path)
	if err != nil {
		return nil, err
	}

	// 2. Allocate the 2KB of internal Work RAM
	ram := make([]byte, 2048)
	c1 := NewController()
	c2 := NewController()
	
	console := Console{
		CPU:         nil,
		PPU:         nil,
		APU:         nil,
		Cartridge:   cartridge,
		Controller1: c1,
		Controller2: c2,
		Mapper:      nil,
		RAM:         ram,
	}

	// 3. Initialize the memory Mapper (currently only Mapper 0 / NROM is supported)
	mapper, err := NewMapper(&console)
	if err != nil {
		return nil, err
	}
	console.Mapper = mapper

	// 4. Initialize the CPU, PPU, and APU with their respective Memory Router Maps
	console.CPU = NewCPU(NewCPUMemory(&console))
	console.PPU = NewPPU(&console)
	console.APU = NewAPU(&console)

	return &console, nil
}

// SetAudioChannel links the APU to a consumer (like Raylib) by providing a Go channel.
func (console *Console) SetAudioChannel(channel chan float32) {
	console.APU.channel = channel
}

// SetAudioSampleRate sets the expected playback rate (usually 44100 Hz).
func (console *Console) SetAudioSampleRate(sampleRate float64) {
	if sampleRate != 0 {
		console.APU.sampleRate = float64(CPUFrequency) / sampleRate
		console.APU.filterChain = FilterChain{
			HighPassFilter(float32(sampleRate), 90),
			HighPassFilter(float32(sampleRate), 440),
			LowPassFilter(float32(sampleRate), 14000),
		}
	}
}

// Reset triggers a hard reset on the CPU.
func (console *Console) Reset() {
	console.CPU.Reset()
}

// Step advances the entire console by exactly 1 CPU instruction.
// Because the PPU runs 3x faster than the CPU, we tick the PPU 3 times for
// every 1 CPU cycle.
func (console *Console) Step() int {
	// Execute 1 CPU instruction, keep track of how many CPU clock cycles it took
	cpuCycles := console.CPU.Step()

	// Tick the APU 1 time for every CPU cycle
	for i := 0; i < cpuCycles; i++ {
		console.APU.Step()
	}

	// Tick the PPU 3 times for every CPU cycle
	ppuCycles := cpuCycles * 3
	for i := 0; i < ppuCycles; i++ {
		console.PPU.Step()
		console.Mapper.Step()
	}

	return cpuCycles
}

// StepFrame repeatedly steps the console until the PPU completes one full 60hz frame (262 scanlines).
func (console *Console) StepFrame() int {
	cpuCycles := 0
	frame := console.PPU.Frame
	for frame == console.PPU.Frame {
		cpuCycles += console.Step()
	}
	return cpuCycles
}

// Buffer returns the fully rendered 256x240 image for the current frame.
func (console *Console) Buffer() *image.RGBA {
	return console.PPU.front
}

// BackgroundColor returns the current universal background color from Palette memory $3F00
func (console *Console) BackgroundColor() color.RGBA { return Palette[console.PPU.readPalette(0)%64] }

// SaveState saves the current console state to a binary file
func (console *Console) SaveState(filename string) error {
	dir, _ := path.Split(filename)
	if dir != "" {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
	}
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()
	encoder := gob.NewEncoder(file)
	return console.Save(encoder)
}

// Save serializes all hardware components internally
func (console *Console) Save(encoder *gob.Encoder) error {
	encoder.Encode(console.RAM)
	console.CPU.Save(encoder)
	console.APU.Save(encoder)
	console.PPU.Save(encoder)
	console.Cartridge.Save(encoder)
	console.Mapper.Save(encoder)
	return encoder.Encode(true)
}

// LoadState loads a previously saved binary state
func (console *Console) LoadState(filename string) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()
	decoder := gob.NewDecoder(file)
	return console.Load(decoder)
}

// Load deserializes the saved hardware state to overwrite current payload
func (console *Console) Load(decoder *gob.Decoder) error {
	decoder.Decode(&console.RAM)
	console.CPU.Load(decoder)
	console.APU.Load(decoder)
	console.PPU.Load(decoder)
	console.Cartridge.Load(decoder)
	console.Mapper.Load(decoder)
	var dummy bool
	if err := decoder.Decode(&dummy); err != nil {
		return err
	}
	return nil
}
