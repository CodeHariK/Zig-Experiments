CROSS = riscv64-elf-
CFLAGS = -march=rv32ima -mabi=ilp32

test:
	go test -v ./... > test_output.txt || true
	cat test_output.txt

test_c:
	go test -run Test_C_CODE -v

c_code:
	$(CROSS)gcc $(CFLAGS) -T test_code/link.ld -nostdlib test_code/bootloader.S test_code/main.c -o test_code/build/main
	$(CROSS)objcopy -O binary -j .text test_code/build/main test_code/build/main.bin
	$(CROSS)objdump -d -M no-aliases,numeric test_code/build/main > test_code/build/disasm.txt
	$(CROSS)readelf -S test_code/build/main > test_code/build/sections.txt
	file test_code/build/main

run_qemu:
	qemu-system-riscv32 -machine sifive_e -nographic -bios none -kernel test_code/main -serial mon:stdio
