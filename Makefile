CC	= ee-gcc
OBJCOPY	= ee-objcopy

.PHONY: all common ee iop

all: common ee iop
	$(CC) -ffreestanding -nostdlib -T common/linkfile.ld -Wl,-N common/*.o ee/*.o iop/*.o -o common/RESET.elf
	$(OBJCOPY) -I elf32-littlemips -O binary common/RESET.elf bin/RESET.bin
	romdir/gen_romdir.py

common:
	$(MAKE) -C common

ee:
	$(MAKE) -C ee

iop:
	$(MAKE) -C iop
