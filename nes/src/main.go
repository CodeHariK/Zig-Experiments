package main

import (
	"image/color"
	"log"
	"os"
	"path/filepath"
	"strings"
	"unsafe"

	rl "github.com/gen2brain/raylib-go/raylib"

	. "github.com/codeharik/nes/src/debug"
	. "github.com/codeharik/nes/src/device"
)

func main() {
	// 1. Initialize Raylib Window
	rl.InitWindow(256*3, 240*3, "Nintendo Entertainment System")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// Don't close on ESC, we'll use it to return to menu
	rl.SetExitKey(0)

	// Initialize Raylib Audio Device (must happen before loading streams)
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	for !rl.WindowShouldClose() {
		var romPath string
		var err error

		if len(os.Args) >= 2 {
			romPath = os.Args[1]
		} else {
			// Show browser if no rom is specified in args
			romPath, err = ShowROMBrowser("roms")
			if err != nil {
				// Window closed or cancelled
				break
			}
		}

		// Run the emulator until user presses ESC
		runRom(romPath)

		// If a rom was passed in args, exit after it finishes instead of looping back to browser
		if len(os.Args) >= 2 {
			break
		}
	}
}

func runRom(romPath string) {
	// Create a floating point Go channel for the APU to push hardware sound waves into
	// 44100 samples per second = about 735 per 60hz frame. 4096 gives it massive breathing room.
	audioChannel := make(chan float32, 4096)

	// Open a hardware playback stream on the OS for 44100Hz, 32-bit floats, 1-channel (Mono!)
	rl.SetAudioStreamBufferSizeDefault(4096)
	audioStream := rl.LoadAudioStream(44100, 32, 1)
	rl.PlayAudioStream(audioStream)
	defer rl.UnloadAudioStream(audioStream)

	// Create the Console
	console, err := NewConsole(romPath)
	if err != nil {
		log.Printf("Failed to initialize Console: %v", err)
		return
	}

	// Tell the Console's audio processing unit exactly what frequency to lock to and where to send it
	console.SetAudioSampleRate(44100.0)
	console.SetAudioChannel(audioChannel)

	// 2. Create a blank Raylib Texture to store our 256x240 NES frames
	image := rl.GenImageColor(256, 240, rl.Blank)
	texture := rl.LoadTextureFromImage(image)
	defer rl.UnloadTexture(texture)
	rl.UnloadImage(image) // Can unload image immediately after creating texture

	// Determine a game-specific save state filename
	saveFile := strings.TrimSuffix(romPath, filepath.Ext(romPath)) + ".state"

	// 3. Main Emulation Loop
	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyEscape) {
			break // Return to the ROM browser loop!
		}

		// Read Keyboard State for Controller 1
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

		if rl.IsKeyPressed(rl.KeyS) {
			err := console.SaveState(saveFile)
			if err != nil {
				log.Printf("Failed to save state: %v", err)
			} else {
				log.Printf("State saved to %s successfully!", saveFile)
			}
		}
		if rl.IsKeyPressed(rl.KeyL) {
			err := console.LoadState(saveFile)
			if err != nil {
				log.Printf("Failed to load state: %v", err)
			} else {
				log.Printf("State loaded from %s successfully!", saveFile)
			}
		}

		// Emulate exactly one 60hz frame
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
