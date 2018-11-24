CC	= ee-gcc
OBJCOPY	= ee-objcopy

.PHONY: all common ee iop

all: common ee iop
	$(CC) -ffreestanding -nostdlib -T common/linkfile.ld -Wl,-N common/*.o ee/*.o iop/*.o -o bios.elf
	$(OBJCOPY) -I elf32-littlemips -O binary --pad-to 0x20000000 bios.elf bios.bin
	dd if=1987.elf of=bios.bin seek=4 bs=1K conv=notrunc status=progress

common:
	$(MAKE) -C common

ee:
	$(MAKE) -C ee

iop:
	$(MAKE) -C iop
