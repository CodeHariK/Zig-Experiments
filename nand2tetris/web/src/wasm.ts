export interface WasmExports {
	assembleProgram: (
		assemblyPtr: number,
		assemblyLen: number,
		binaryPtr: number,
		binaryLen: number
	) => number
	disassembleProgram: (
		binaryPtr: number,
		binaryLen: number,
		outputPtr: number,
		outputLen: number,
		emitSymbols: number
	) => number
}

var memory = new WebAssembly.Memory({
	// See build.zig for reasoning (160 pages = 10MB)
	initial: 160 /* pages */,
	maximum: 160 /* pages */,
})

var importObject = {
	env: {
		consoleLog: (arg: unknown) => console.log(arg), // Useful for debugging on zig's side
		memory: memory,
	},
}

let wasmExports: WasmExports | null = null

export async function loadWasm(): Promise<WasmExports> {
	if (wasmExports) {
		return wasmExports
	}

	const result = await WebAssembly.instantiateStreaming(fetch("/nand2tetris.wasm"), importObject)
	wasmExports = result.instance.exports as unknown as WasmExports

	return wasmExports
}

export function getWasm(): WasmExports | null {
	return wasmExports
}

// Helper functions to work with WASM memory
export function assembleProgram(assembly: string): Uint16Array | null {
	const w = getWasm()
	if (!w) return null

	const memoryView = new Uint8Array(memory.buffer)
	const assemblyPtr = 2048 // Use offset 2048 for assembly input
	const binaryPtr = 4096 // Use offset 4096 for binary output (as u16 array)

	// Write assembly string to memory
	const encoder = new TextEncoder()
	// Ensure assembly ends with newline for proper parsing
	const assemblyWithNewline = assembly.endsWith("\n") ? assembly : `${assembly}\n`
	const assemblyBytes = encoder.encode(assemblyWithNewline)
	if (assemblyBytes.length > 2048) return null // Too large

	// Clear the assembly area first
	memoryView.fill(0, assemblyPtr, 2048)
	memoryView.set(assemblyBytes, assemblyPtr)

	// Debug: log what we're sending
	console.log("Assembling:", assemblyWithNewline)
	console.log("Assembly bytes length:", assemblyBytes.length)

	// Assemble
	const binaryLen = 1024 // Max 1024 instructions
	const wordCount = w.assembleProgram(assemblyPtr, assemblyBytes.length, binaryPtr, binaryLen)
	if (wordCount === 0) {
		console.error("Assembly failed: wordCount is 0")
		return null
	}

	// Read binary result
	// binaryPtr is a byte offset, but Uint16Array uses word indices, so divide by 2
	const binaryView = new Uint16Array(memory.buffer)
	const wordOffset = binaryPtr / 2 // Convert byte offset to word index
	const result = new Uint16Array(wordCount)
	result.set(binaryView.subarray(wordOffset, wordOffset + wordCount))

	// Debug: log the result
	console.log("Assembly result wordCount:", wordCount)
	console.log(
		"Binary result:",
		Array.from(result).map((v) => `0x${v.toString(16).padStart(4, "0").toUpperCase()}`)
	)

	// Check if result is all zeros (likely an error)
	if (result.every((v) => v === 0)) {
		console.error("Assembly result is all zeros - likely parsing error")
		console.error("Input assembly was:", assembly)
		return null
	}

	return result
}

export function disassembleProgram(binary: Uint16Array, emitSymbols: boolean): string | null {
	const w = getWasm()
	if (!w) return null

	const memoryView = new Uint8Array(memory.buffer)
	const binaryPtr = 4096 // Use offset 4096 for binary input (as u16 array)
	const outputPtr = 2048 // Use offset 2048 for assembly output

	// Write binary to memory
	// binaryPtr is a byte offset, but Uint16Array uses word indices, so divide by 2
	const binaryView = new Uint16Array(memory.buffer)
	if (binary.length > 1024) return null // Too large
	const wordOffset = binaryPtr / 2 // Convert byte offset to word index
	binaryView.set(binary, wordOffset)

	// Disassemble
	const outputLen = 8192 // Max 8KB output
	const bytesWritten = w.disassembleProgram(
		binaryPtr,
		binary.length,
		outputPtr,
		outputLen,
		emitSymbols ? 1 : 0
	)
	if (bytesWritten === 0) return null

	// Read assembly result
	const decoder = new TextDecoder()
	return decoder.decode(memoryView.subarray(outputPtr, outputPtr + bytesWritten))
}
