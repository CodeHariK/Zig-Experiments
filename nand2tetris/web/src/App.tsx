import { createSignal, onMount, Show, createEffect } from "solid-js"

import { loadWasm, assembleProgram, disassembleProgram } from "./wasm"

import 'gridstack/dist/gridstack.min.css';
import { GridStack } from 'gridstack';

import "./App.css"

function App() {
	const [wasm, setWasm] = createSignal(false)
	const [loading, setLoading] = createSignal(true)
	const [error, setError] = createSignal<string | null>(null)

	const [assemblyInput, setAssemblyInput] = createSignal("@5\nD=A\nM=D+1")
	const [binaryInput, setBinaryInput] = createSignal("0x0005,0xEC10,0xE7D1")
	const [emitSymbols, setEmitSymbols] = createSignal(false)
	
	// Use non-reactive refs to prevent circular updates
	let updatingAssembly = false
	let updatingBinary = false
	let lastAssemblyValue = ""
	let lastBinaryValue = ""

	let gridStackContainer: HTMLDivElement | undefined

	onMount(async () => {
		try {
			await loadWasm()
			setWasm(true)
			setLoading(false)

			// Initialize GridStack after WASM loads
			if (gridStackContainer) {
				GridStack.init(
					{
						column: 12,
						cellHeight: 70,
						margin: 10,
						disableResize: true,
						disableDrag: true,
					},
					gridStackContainer
				)
			}
		} catch (err) {
			setError(err instanceof Error ? err.message : "Unknown error")
			setLoading(false)
		}
	})

	// Auto-assemble when assembly input changes
	createEffect(() => {
		if (!wasm() || updatingBinary) return
		
		const assembly = assemblyInput()
		
		// Skip if value hasn't changed
		if (assembly === lastAssemblyValue) return
		lastAssemblyValue = assembly
		
		if (!assembly.trim()) {
			if (binaryInput() !== "") {
				updatingAssembly = true
				setBinaryInput("")
				updatingAssembly = false
			}
			return
		}

		updatingAssembly = true
		const binary = assembleProgram(assembly)
		if (binary && binary.length > 0) {
			const binStr = Array.from(binary)
				.map((v) => v.toString(2).padStart(16, "0"))
				.join("\n")
			if (binStr !== lastBinaryValue) {
				lastBinaryValue = binStr
				setBinaryInput(binStr)
			}
		} else {
			// Assembly failed - clear binary or show error
			if (binaryInput() !== "") {
				lastBinaryValue = ""
				setBinaryInput("")
			}
		}
		updatingAssembly = false
	})

	// Auto-disassemble when binary input changes
	createEffect(() => {
		if (!wasm() || updatingAssembly) return

		const binaryStr = binaryInput()
		
		// Skip if value hasn't changed
		if (binaryStr === lastBinaryValue) return
		lastBinaryValue = binaryStr

		if (!binaryStr.trim()) {
			if (assemblyInput() !== "") {
				updatingBinary = true
				setAssemblyInput("")
				updatingBinary = false
			}
			return
		}

		// Parse binary input (comma or newline-separated binary or hex values)
		const hexValues = binaryStr
			.split(/[,\n]/)
			.map((s) => s.trim())
			.filter((s) => s.length > 0)
			.map((s) => {
				// Check if it's binary (all 0s and 1s, length 16)
				if (/^[01]{16}$/.test(s)) {
					return parseInt(s, 2)
				}
				// Otherwise try hex (remove 0x prefix if present)
				const cleaned = s.startsWith("0x") || s.startsWith("0X") ? s.slice(2) : s
				return parseInt(cleaned, 16)
			})
			.filter((n) => !Number.isNaN(n))

		if (hexValues.length === 0) return

		updatingBinary = true
		const binary = new Uint16Array(hexValues)
		const assembly = disassembleProgram(binary, emitSymbols())
		if (assembly) {
			const trimmed = assembly.trim()
			if (trimmed !== lastAssemblyValue) {
				lastAssemblyValue = trimmed
				setAssemblyInput(trimmed)
			}
		}
		updatingBinary = false
	})

	return (
		<div class="container">
			<h1 class="title">Nand2Tetris WASM Assembler</h1>

			<Show when={loading()}>
				<div class="loading">Loading WASM module...</div>
			</Show>

			<Show when={error()}>
				<div class="error">Error: {error()}</div>
			</Show>

			<Show when={!loading() && !error() && wasm()}>
				<div class="input-group" style="margin-bottom: 10px;">
					<label class="checkbox-group">
						<input
							type="checkbox"
							checked={emitSymbols()}
							onChange={(e) => setEmitSymbols(e.currentTarget.checked)}
						/>
						Emit symbols
					</label>
				</div>

				<div ref={gridStackContainer} class="grid-stack">
					{/* Assembly Input */}
					<div class="grid-stack-item" gs-w="6" gs-h="8">
						<div class="card" style="height: 100%; display: flex; flex-direction: column;">
							<h2 class="card-title">Assembly</h2>
							<textarea
								value={assemblyInput()}
								onInput={(e) => setAssemblyInput(e.currentTarget.value)}
								class="textarea"
								style="flex: 1; resize: none; font-family: monospace;"
								placeholder="Enter assembly code..."
							/>
						</div>
					</div>

					{/* Binary Input */}
					<div class="grid-stack-item" gs-w="6" gs-h="8">
						<div class="card" style="height: 100%; display: flex; flex-direction: column;">
							<h2 class="card-title">Machine Code (Binary)</h2>
							<textarea
								value={binaryInput()}
								onInput={(e) => setBinaryInput(e.currentTarget.value)}
								class="textarea"
								style="flex: 1; resize: none; font-family: monospace;"
								placeholder="Enter binary code (16-bit binary, one per line)..."
							/>
						</div>
					</div>
				</div>
			</Show>
		</div>
	)
}

export default App
