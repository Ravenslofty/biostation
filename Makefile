CC	= ee-gcc
OBJCOPY	= ee-objcopy

.PHONY: all common ee iop

all: rom.bin
	printf "\aYour BIOS is ready; get it while it's hot.\n"

romdir.bin rom.bin: bin/RESET.bin bin/EEKERNEL.elf 
	romdir/gen_romdir.py

bin/RESET.bin: common/RESET.elf
	$(OBJCOPY) -I elf32-littlemips -O binary common/RESET.elf bin/RESET.bin

bin/EEKERNEL.elf: ee/EEKERNEL.elf
	cp ee/EEKERNEL.elf bin/

bin/LOADCORE.irx: iop/LOADCORE.irx
	cp iop/loadcore/LOADCORE.irx

ee/EEKERNEL.elf: $(wildcard ee/*.c ee/*.h ee/*.S include/*.h)
	$(MAKE) -C ee

common/RESET.elf: $(wildcard common/*.c common/*.h common/*.S include/*.h)
	$(MAKE) -C common

iop/LOADCORE.irx:
	$(MAKE) -C iop/loadcore
