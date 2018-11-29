# SPDX-License-Identifier: GPL-3.0-or-later
CC	= ee-gcc

CFLAGS	= -O3 -ffreestanding -std=gnu99 -I../include -G0 -Wall
ASFLAGS	= -I../include

FILES	= bootstrap.o gs.o intc_dmac.o start.o thread.o ../common/elf.o ../common/mem.o ../common/romdir.o ../common/stdout.o

all: $(FILES)
	$(CC) -ffreestanding -nostdlib -T linkfile.ld -Wl,-N $(FILES) -o EEKERNEL.elf
