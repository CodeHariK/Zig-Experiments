.PHONY: test
test:
	mkdir -p test && \
	zig build install && \
	(./zig-out/bin/test-gates > test/test_gates.txt 2>&1 &) && \
	(./zig-out/bin/test-memory > test/test_memory.txt 2>&1 &) && \
	wait
