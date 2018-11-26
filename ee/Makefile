# SPDX-License-Identifier: GPL-3.0-or-later
CC	= ee-gcc

CFLAGS	= -O3 -ffreestanding -std=gnu99 -I../include -G0 -Wall
ASFLAGS	= -I../include

FILES	= bootstrap.o gs.o intc_dmac.o mem.o romdir.o start.o stdout.o thread.o

all: $(FILES)
