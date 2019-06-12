// SPDX-License-Identifier: GPL-3.0-or-later

#include "mem.h"
#include "types.h"

struct Entry {
    char name[10];
    u16 info_size;
    u32 file_size;
} __attribute__((packed));

char* romdir_lookup(const char* name)
{
    // Look for the RESET string that marks the beginning of the ROMDIR table.
    // Note that we can't use strcmp because that would put the "RESET" string in the wrong place.
    char* rom_ptr = (char*)0x9fc00000;

    while ((int)rom_ptr < 0x20000000) {
        if (rom_ptr[0] == 'R' &&
            rom_ptr[1] == 'E' &&
            rom_ptr[2] == 'S' &&
            rom_ptr[3] == 'E' &&
            rom_ptr[4] == 'T') {

            break;
        }

        rom_ptr++;
    }

    if ((int)rom_ptr >= 0x20000000) {
        //ee_kwrite("[!!] romdir_lookup: Couldn't find start of ROMDIR\n");

        asm volatile("break");
    }

    struct Entry* romdir = (struct Entry*)rom_ptr;
    rom_ptr = (char*)0x1fc00000;

    for (; romdir->file_size != 0; romdir++) {
        if (strlen(romdir->name) == strlen(name)) {
            int i = 0;
            for (; i < strlen(romdir->name); i++) {
                if (romdir->name[i] != name[i]) {
                    break;
                }
            }
            if (i == strlen(romdir->name)) {
                return rom_ptr;
            }
        }

        rom_ptr += romdir->file_size;
    }

    //ee_kwrite("[!!] romdir_lookup: Couldn't find entry in ROMDIR\n");

    asm volatile("break");
    // unreachable
}
