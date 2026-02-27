package debug

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	. "github.com/codeharik/nes/src/device"
)

// mapCPUAddressToPhysical maps a physical CPU address ($8000-$FFFF) to all possible PRG offsets.
func mapCPUAddressToPhysical(addr int, prgSize int) []int {
	var offsets []int
	if addr < 0x8000 {
		return offsets
	}

	if prgSize <= 0x4000 { // 16KB
		offsets = append(offsets, (addr-0x8000)%0x4000)
	} else if prgSize == 0x8000 { // 32KB
		offsets = append(offsets, addr-0x8000)
	} else { // > 32KB banked ROM
		if addr >= 0xE000 {
			// Assume the last 8KB is fixed
			offsets = append(offsets, prgSize-0x2000+(addr-0xE000))
		} else {
			// Could be any 8KB bank!
			bankOff := addr & 0x1FFF
			for b := 0; b < prgSize; b += 0x2000 {
				offsets = append(offsets, b+bankOff)
			}
		}
	}
	return offsets
}

func physicalToCPU(offset int, prgSize int) int {
	if prgSize <= 0x4000 {
		return 0x8000 + (offset % 0x4000)
	} else if prgSize == 0x8000 {
		return 0x8000 + offset
	} else {
		// Just guess standard 8KB window for switchable banks
		if offset >= prgSize-0x2000 {
			return 0xE000 + (offset % 0x2000)
		}
		// Treat switchable banks as starting at $8000 locally
		return 0x8000 + (offset % 0x2000)
	}
}

// DisassembleROM reads the ROM from the path and extracts subroutines to files using a 2-pass sweep.
func DisassembleROM(romPath string) error {
	cart, err := LoadROM(romPath)
	if err != nil {
		return fmt.Errorf("Failed to load ROM: %v", err)
	}

	prg := cart.PRG
	size := len(prg)

	baseName := strings.TrimSuffix(filepath.Base(romPath), filepath.Ext(romPath))
	outDir := filepath.Join(filepath.Dir(romPath), baseName+"_disassembly")
	os.MkdirAll(outDir, 0755)

	fmt.Printf("Analyzing %s...\n", romPath)
	fmt.Printf("PRG ROM Size: %d KB\n", size/1024)

	// Pass 1: Identify all labels
	isSubroutine := make(map[int]string)
	isBranchTarget := make(map[int]string)

	if size >= 6 {
		nmi := int(prg[size-6]) | (int(prg[size-5]) << 8)
		res := int(prg[size-4]) | (int(prg[size-3]) << 8)
		irq := int(prg[size-2]) | (int(prg[size-1]) << 8)

		for _, off := range mapCPUAddressToPhysical(nmi, size) {
			isSubroutine[off] = fmt.Sprintf("NMI_%04X", nmi)
		}
		for _, off := range mapCPUAddressToPhysical(res, size) {
			isSubroutine[off] = fmt.Sprintf("RESET_%04X", res)
		}
		for _, off := range mapCPUAddressToPhysical(irq, size) {
			isSubroutine[off] = fmt.Sprintf("IRQ_%04X", irq)
		}
	}

	isBranch := map[byte]bool{0x10: true, 0x30: true, 0x50: true, 0x70: true, 0x90: true, 0xB0: true, 0xD0: true, 0xF0: true}

	for i := 0; i < size-2; i++ {
		opcode := prg[i]
		if opcode == 0x20 { // JSR
			addr := int(prg[i+1]) | (int(prg[i+2]) << 8)
			for _, off := range mapCPUAddressToPhysical(addr, size) {
				if _, ok := isSubroutine[off]; !ok {
					isSubroutine[off] = fmt.Sprintf("sub_%04X", addr)
				}
			}
		} else if isBranch[opcode] {
			rel := int8(prg[i+1])
			targetOff := i + 2 + int(rel)
			if targetOff >= 0 && targetOff < size {
				if _, ok := isBranchTarget[targetOff]; !ok {
					isBranchTarget[targetOff] = fmt.Sprintf("loc_%04X", physicalToCPU(targetOff, size))
				}
			}
		}
	}

	// Pass 2: Linear Sweep and output
	var currentFile *os.File
	currentFileName := ""

	closeFile := func() {
		if currentFile != nil {
			currentFile.Close()
			currentFile = nil
		}
	}
	defer closeFile()

	openFile := func(filename string) error {
		closeFile()
		f, err := os.Create(filepath.Join(outDir, filename))
		if err == nil {
			currentFile = f
			currentFileName = filename
		}
		return err
	}

	for offset := 0; offset < size; {
		// New subroutine threshold
		if subName, ok := isSubroutine[offset]; ok {

			bankId := offset / 8192
			bankDir := filepath.Join(outDir, fmt.Sprintf("Bank%02X", bankId))
			os.MkdirAll(bankDir, 0755)

			filename := filepath.Join(fmt.Sprintf("Bank%02X", bankId), subName+".asm")
			if currentFileName != filename { // prevent reopening identical
				openFile(filename)
				currentFile.WriteString(fmt.Sprintf("%s:\n", subName))
			}
		} else if currentFile == nil {
			// Fallback if we start with no subroutine
			bankId := offset / 8192
			bankDir := filepath.Join(outDir, fmt.Sprintf("Bank%02X", bankId))
			os.MkdirAll(bankDir, 0755)

			filename := filepath.Join(fmt.Sprintf("Bank%02X", bankId), fmt.Sprintf("data_%05X.asm", offset))
			openFile(filename)
			currentFile.WriteString(fmt.Sprintf("data_%05X:\n", offset))
		}

		// Local branch target label
		if locName, ok := isBranchTarget[offset]; ok {
			currentFile.WriteString(fmt.Sprintf("%s:\n", locName))
		}

		opcode := prg[offset]
		instSize := int(InstructionSizes[opcode])
		name := InstructionNames[opcode]

		if name == "" {
			name = "???"
		}

		// Lookahead to prevent instructions masking branch labels
		if instSize > 1 {
			for j := 1; j < instSize; j++ {
				if offset+j < size {
					_, hasSub := isSubroutine[offset+j]
					_, hasLoc := isBranchTarget[offset+j]
					if hasSub || hasLoc {
						instSize = j
						name = "???"
						break
					}
				}
			}
		}

		var instructionText string
		if name == "???" {
			// invalid instruction or masked by lookahead
			instructionText = fmt.Sprintf("    %02X       .byte $%02X", opcode, opcode)
			instSize = 1
		} else {
			switch instSize {
			case 1:
				instructionText = fmt.Sprintf("    %02X       %s", opcode, name)
			case 2:
				if offset+1 < size {
					arg1 := prg[offset+1]
					instructionText = fmt.Sprintf("    %02X %02X    %s $%02X", opcode, arg1, name, arg1)
				} else {
					instructionText = fmt.Sprintf("    %02X       .byte $%02X", opcode, opcode)
					instSize = 1
				}
			case 3:
				if offset+2 < size {
					arg1 := prg[offset+1]
					arg2 := prg[offset+2]
					instructionText = fmt.Sprintf("    %02X %02X %02X %s $%02X%02X", opcode, arg1, arg2, name, arg2, arg1)
				} else {
					instructionText = fmt.Sprintf("    %02X       .byte $%02X", opcode, opcode)
					instSize = 1
				}
			default:
				instructionText = fmt.Sprintf("    %02X       .byte $%02X", opcode, opcode)
				instSize = 1
			}
		}

		if currentFile != nil {
			currentFile.WriteString(instructionText + "\n")
		}

		offset += instSize
	}

	fmt.Printf("Successfully saved subroutines to %s/\n", outDir)
	return nil
}
