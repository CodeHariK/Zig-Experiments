CROSS = riscv64-elf-
CFLAGS = -march=rv32ima -mabi=ilp32 -fomit-frame-pointer -O0

test:
	make c_code
	go test -v ./... > test_output.txt || true
	echo "Fails: $$(grep -ic fail test_output.txt), Passes: $$(grep -ic pass test_output.txt)"

c_code:
	$(CROSS)gcc $(CFLAGS) -T test_code/link.ld -nostdlib test_code/bootloader.S test_code/main.c -o test_code/build/main
	$(CROSS)objcopy -O binary -j .text test_code/build/main test_code/build/main.bin
	$(CROSS)objdump -d -M no-aliases,numeric test_code/build/main > test_code/build/disasm.txt
	$(CROSS)readelf -S test_code/build/main > test_code/build/sections.txt
	file test_code/build/main

run_qemu:
	qemu-system-riscv32 -machine sifive_e -nographic -bios none -kernel test_code/build/main -serial mon:stdio
