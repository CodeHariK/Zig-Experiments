package debug

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	rl "github.com/gen2brain/raylib-go/raylib"
)

// ShowROMBrowser displays a visual grid of .nes files in the given directory
// and returns the path to the selected ROM.
func ShowROMBrowser(directory string) (string, error) {
	files, err := os.ReadDir(directory)
	if err != nil {
		return "", err
	}

	var roms []string
	for _, f := range files {
		if !f.IsDir() && strings.HasSuffix(strings.ToLower(f.Name()), ".nes") {
			roms = append(roms, filepath.Join(directory, f.Name()))
		}
	}

	if len(roms) == 0 {
		return "", fmt.Errorf("no .nes ROMs found in directory %q", directory)
	}

	selectedIndex := 0

	cols := 3
	margin := int32(40)
	padding := int32(20)

	// Wait for Enter key to be released if it was pressed to start
	for rl.IsKeyDown(rl.KeyEnter) {
		rl.BeginDrawing()
		rl.ClearBackground(rl.DarkGray)
		rl.EndDrawing()
	}

	for !rl.WindowShouldClose() {
		// Input handling
		if rl.IsKeyPressed(rl.KeyRight) {
			selectedIndex++
			if selectedIndex >= len(roms) {
				selectedIndex = len(roms) - 1
			}
		}
		if rl.IsKeyPressed(rl.KeyLeft) {
			selectedIndex--
			if selectedIndex < 0 {
				selectedIndex = 0
			}
		}
		if rl.IsKeyPressed(rl.KeyDown) {
			selectedIndex += cols
			if selectedIndex >= len(roms) {
				selectedIndex = len(roms) - 1
			}
		}
		if rl.IsKeyPressed(rl.KeyUp) {
			selectedIndex -= cols
			if selectedIndex < 0 {
				selectedIndex = 0
			}
		}

		if rl.IsKeyPressed(rl.KeyD) {
			err := DisassembleROM(roms[selectedIndex])
			if err != nil {
				fmt.Printf("Error disassembling: %v\n", err)
			}
		}

		if rl.IsKeyPressed(rl.KeyC) {
			ShowSpriteViewer(roms[selectedIndex])
		}

		if rl.IsKeyPressed(rl.KeyA) {
			ShowAudioInfo(roms[selectedIndex])
		}

		if rl.IsKeyPressed(rl.KeyEnter) {
			return roms[selectedIndex], nil
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.DarkGray)

		rl.DrawText("Select a ROM", margin, margin, 30, rl.RayWhite)

		startX := margin
		startY := margin + 60

		for i, romPath := range roms {
			row := int32(i / cols)
			col := int32(i % cols)

			// Extract just the filename without extension for display
			name := filepath.Base(romPath)
			name = strings.TrimSuffix(name, filepath.Ext(name))

			// Truncate name if too long
			if len(name) > 13 {
				name = name[:10] + "..."
			}

			// Define cell bounds
			cellWidth := (int32(rl.GetScreenWidth()) - (margin * 2) - (padding * int32(cols-1))) / int32(cols)
			cellHeight := int32(40)

			x := startX + (col * (cellWidth + padding))
			y := startY + (row * (cellHeight + padding))

			// Draw selection highlight
			if i == selectedIndex {
				rl.DrawRectangle(x, y, cellWidth, cellHeight, rl.Blue)
				rl.DrawRectangleLines(x, y, cellWidth, cellHeight, rl.White)
				rl.DrawText(name, x+10, y+10, 20, rl.White)
			} else {
				rl.DrawRectangle(x, y, cellWidth, cellHeight, rl.LightGray)
				rl.DrawRectangleLines(x, y, cellWidth, cellHeight, rl.Black)
				rl.DrawText(name, x+10, y+10, 20, rl.Black)
			}
		}

		// Draw Keyboard Controls Help
		helpY := int32(rl.GetScreenHeight()) - margin - 50

		rl.DrawText("D-Pad: Arrows    [Z]    [X]    Start: Enter    Select: R-Shift", margin, helpY, 20, rl.RayWhite)
		rl.DrawText("[C] View Sprites | [A] Audio Info | [D] Extract Code", margin, helpY+30, 20, rl.SkyBlue)
		rl.EndDrawing()
	}

	return "", fmt.Errorf("window closed before selection")
}
