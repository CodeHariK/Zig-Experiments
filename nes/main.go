package main

import (
	"fmt"
	"image/color"
	"log"
	"os"
	"unsafe"

	"github.com/codeharik/nes/src"
	rl "github.com/gen2brain/raylib-go/raylib"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run . <rom.nes>")
		os.Exit(1)
	}

	// 1. Initialize Raylib Window
	rl.InitWindow(256*3, 240*3, "Nintendo Entertainment System")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// Initialize Raylib Audio Device
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()
	
	// Create a floating point Go channel for the APU to push hardware sound waves into
	// 44100 samples per second = about 735 per 60hz frame. 4096 gives it massive breathing room.
	audioChannel := make(chan float32, 4096)
	
	// Open a hardware playback stream on the OS for 44100Hz, 32-bit floats, 1-channel (Mono!)
	rl.SetAudioStreamBufferSizeDefault(4096)
	audioStream := rl.LoadAudioStream(44100, 32, 1)
	rl.PlayAudioStream(audioStream)
	defer rl.UnloadAudioStream(audioStream)

	// Create the Console
	console, err := src.NewConsole(os.Args[1])
	if err != nil {
		log.Fatalf("Failed to initialize Console: %v", err)
	}

	// Tell the Console's audio processing unit exactly what frequency to lock to and where to send it
	console.SetAudioSampleRate(44100.0)
	console.SetAudioChannel(audioChannel)

	// 2. Create a blank Raylib Texture to store our 256x240 NES frames
	// We use an image first to allocate it, then convert to a hardware Texture
	image := rl.GenImageColor(256, 240, rl.Blank)
	texture := rl.LoadTextureFromImage(image)
	defer rl.UnloadTexture(texture)
	rl.UnloadImage(image) // Can unload image immediately after creating texture

	// 3. Main Emulation Loop
	for !rl.WindowShouldClose() {
		// Read Keyboard State for Controller 1
		// NES Mapping: A=Z, B=X, Select=RightShift, Start=Enter, D-Pad = Arrow Keys
		buttons := [8]bool{
			rl.IsKeyDown(rl.KeyZ),
			rl.IsKeyDown(rl.KeyX),
			rl.IsKeyDown(rl.KeyRightShift),
			rl.IsKeyDown(rl.KeyEnter),
			rl.IsKeyDown(rl.KeyUp),
			rl.IsKeyDown(rl.KeyDown),
			rl.IsKeyDown(rl.KeyLeft),
			rl.IsKeyDown(rl.KeyRight),
		}
		console.Controller1.SetButtons(buttons)

		// Emulate exactly one 60hz frame (approx 29780 CPU cycles)
		console.StepFrame()

		// Drain the `audioChannel` from the APU and pump it smoothly to Raylib
		if rl.IsAudioStreamProcessed(audioStream) {
			samples := make([]float32, 0, 4096)
		drain:
			for len(samples) < 4096 {
				select {
				case sample := <-audioChannel:
					samples = append(samples, sample)
				default:
					break drain
				}
			}

			if len(samples) > 0 {
				rl.UpdateAudioStream(audioStream, samples)
			}
		}

		// Get the frame buffer background array (image.RGBA)
		buffer := console.Buffer()

		// Unsafe update texture with raw RGBA byte pixels directly from Go memory
		// Raylib requires []color.RGBA, but our buffer is []byte. Since RGBA is 4 bytes,
		// we can precisely unsafe cast the memory to zero-copy update the GPU!
		pixels := unsafe.Slice((*color.RGBA)(unsafe.Pointer(&buffer.Pix[0])), len(buffer.Pix)/4)
		rl.UpdateTexture(texture, pixels)

		// 4. Draw to Screen
		rl.BeginDrawing()
		rl.ClearBackground(rl.Black)

		// Draw the 256x240 texture scaled up 3x to fit our 768x720 window
		sourceRec := rl.NewRectangle(0, 0, float32(texture.Width), float32(texture.Height))
		destRec := rl.NewRectangle(0, 0, float32(256*3), float32(240*3))
		rl.DrawTexturePro(texture, sourceRec, destRec, rl.NewVector2(0, 0), 0, rl.White)

		rl.EndDrawing()
	}
}
