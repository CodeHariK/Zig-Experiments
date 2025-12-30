.PHONY: test test-logic test-memory test-mach test-machine wasm
test:
	mkdir -p test && \
	zig build install && \
	(./zig-out/bin/test-logic > test/test_logic.txt 2>&1 &) && \
	(./zig-out/bin/test-memory > test/test_memory.txt 2>&1 &) && \
	(./zig-out/bin/test-machine-language > test/test_machine_language.txt 2>&1 &) && \
	(./zig-out/bin/test-machine > test/test_machine.txt 2>&1 &) && \
	wait

test-logic:
	mkdir -p test && \
	zig build install && \
	./zig-out/bin/test-logic > test/test_logic.txt 2>&1

test-memory:
	mkdir -p test && \
	zig build install && \
	./zig-out/bin/test-memory > test/test_memory.txt 2>&1

test-language:
	mkdir -p test && \
	zig build install && \
	./zig-out/bin/test-machine-language > test/test_machine_language.txt 2>&1

test-machine:
	mkdir -p test && \
	zig build install && \
	./zig-out/bin/test-machine > test/test_machine.txt 2>&1

test-vm:
	mkdir -p test && \
	zig build install && \
	./zig-out/bin/test-vm-translator > test/test_vm_translator.txt 2>&1

wasm:
	zig build wasm -Doptimize=ReleaseSmall
	mkdir -p web/public && \
	cp zig-out/bin/nand2tetris.wasm web/public/
