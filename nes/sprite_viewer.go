package main

import (
	"fmt"
	"path/filepath"

	"github.com/codeharik/nes/src"
	rl "github.com/gen2brain/raylib-go/raylib"
)

func ShowSpriteViewer(romPath string) {
	cart, err := src.LoadROM(romPath)
	if err != nil {
		fmt.Println("Error loading ROM for sprites:", err)
		return
	}

	palette := []rl.Color{rl.Black, rl.DarkGray, rl.LightGray, rl.White}

	numTiles := len(cart.CHR) / 16

	cols := 32
	rows := (numTiles + cols - 1) / cols

	scale := int32(2)
	screenHeight := int32(rows*8) * scale
	windowHeight := int32(720)
	if windowHeight > screenHeight {
		windowHeight = screenHeight
	}

	scrollY := int32(0)

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyEscape) {
			break
		}

		if rl.IsKeyDown(rl.KeyUp) {
			scrollY -= 16
		}
		if rl.IsKeyDown(rl.KeyDown) {
			scrollY += 16
		}

		maxScroll := screenHeight - windowHeight + 100 // extra padding
		if maxScroll < 0 {
			maxScroll = 0
		}
		if scrollY < 0 {
			scrollY = 0
		}
		if scrollY > maxScroll {
			scrollY = maxScroll
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{20, 20, 20, 255})

		if numTiles == 0 {
			rl.DrawText("No CHR ROM found (game uses CHR RAM)", 40, 40, 20, rl.Red)
		} else {
			for t := 0; t < numTiles; t++ {
				col := t % cols
				row := t / cols

				x := int32(col*8)*scale + 20
				y := int32(row*8)*scale - scrollY + 40

				if y+8*scale < 0 || y > 720 {
					continue
				}

				for py := 0; py < 8; py++ {
					plane0 := cart.CHR[t*16+py]
					plane1 := cart.CHR[t*16+py+8]

					for px := 0; px < 8; px++ {
						bit0 := (plane0 >> (7 - px)) & 1
						bit1 := (plane1 >> (7 - px)) & 1
						colorIdx := (bit1 << 1) | bit0

						color := palette[colorIdx]
						rl.DrawRectangle(x+int32(px)*scale, y+int32(py)*scale, scale, scale, color)
					}
				}
			}
		}

		// Draw Header over sprites
		rl.DrawRectangle(0, 0, 800, 35, rl.Black)
		rl.DrawText(fmt.Sprintf("Sprites for %s - Use ARROWS to scroll, ESC to return", filepath.Base(romPath)), 10, 10, 20, rl.Red)

		rl.EndDrawing()
	}
}
