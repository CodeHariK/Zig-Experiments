package main

import (
	"fmt"
	"path/filepath"

	"github.com/codeharik/nes/src"
	rl "github.com/gen2brain/raylib-go/raylib"
)

func ShowAudioInfo(romPath string) {
	cart, err := src.LoadROM(romPath)
	if err != nil {
		fmt.Println("Error loading ROM:", err)
		return
	}

	expansionAudio := "None"
	switch cart.Mapper {
	case 5:
		expansionAudio = "MMC5 (2 Square, 1 PCM)"
	case 19:
		expansionAudio = "Namco 163 (1-8 Wavetable channels)"
	case 24, 26:
		expansionAudio = "VRC6 (2 Square, 1 Sawtooth)"
	case 69:
		expansionAudio = "Sunsoft 5B (3 Square/Noise)"
	case 85:
		expansionAudio = "VRC7 (6 FM Synthesis)"
	}

	lines := []string{
		fmt.Sprintf("Audio & Asset Information for %s", filepath.Base(romPath)),
		"--------------------------------------------------",
		"Base NES APU Channels:",
		"  - Pulse 1  (Square wave, sweep, envelope)",
		"  - Pulse 2  (Square wave, sweep, envelope)",
		"  - Triangle (Bass lines, pseudo-DPCM)",
		"  - Noise    (Percussion, RNG generation)",
		"  - DPCM     (Delta modulation samples, 1-bit)",
		"",
		"Expansion Audio:",
		"  - " + expansionAudio,
		"",
		"Asset Extraction:",
		fmt.Sprintf("  - PRG ROM: %d KB", len(cart.PRG)/1024),
		fmt.Sprintf("  - CHR ROM: %d KB", len(cart.CHR)/1024),
		fmt.Sprintf("  - Mapper ID: %d", cart.Mapper),
		fmt.Sprintf("  - Battery Supported: %v", cart.Battery == 1),
	}

	// Just reuse the active display window until ESC
	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyEscape) {
			break
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.DarkGray)

		for i, line := range lines {
			color := rl.RayWhite
			if i == 0 {
				color = rl.Gold
			}
			rl.DrawText(line, 40, int32(40+i*30), 20, color)
		}

		rl.DrawText("Press ESC to return", 40, int32(40+len(lines)*30+40), 20, rl.SkyBlue)
		rl.EndDrawing()
	}
}
