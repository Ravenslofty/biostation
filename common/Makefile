# SPDX-License-Identifier: GPL-3.0-or-later

CC	= ee-gcc
CFLAGS	= -O3 -std=gnu99 -I../include -G0 -Wall
ASFLAGS	= -I../include -G0
FILES	= elf.o mem.o romdir.o start.o stdout.o

all: $(FILES)
	$(CC) -ffreestanding -nostdlib -T linkfile.ld -Wl *.o -o RESET.elf

