// SPDX-License-Identifier: GPL-3.0-or-later

void ee_kwrite(const char* buf, unsigned int count)
{
    volatile char* const ee_debug_out = (volatile char*)0x1000F180;

    for (unsigned int i = 0; i < count; i++) {
        *ee_debug_out = buf[i];
    }
}

