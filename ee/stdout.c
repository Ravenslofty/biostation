// SPDX-License-Identifier: GPL-3.0-or-later

#include "mem.h"

void ee_kwrite(const char* buf)
{
    unsigned int count = strlen(buf);
    volatile char* const ee_debug_out = (volatile char*)0x1000F180;

    for (unsigned int i = 0; i < count; i++) {
        *ee_debug_out = buf[i];
    }
}

