// SPDX-License-Identifier: GPL-3.0-or-later
#include "locations.h"
#include "types.h"

u64* gs_imr = (u64*)GS_INTERRUPT_MASK;

void ee_gs_set_crt(bool interlaced, int display_mode, bool frame)
{
    // STUB: PSI really doesn't want to deal with this.
}

u64 ee_gs_get_imr()
{
    return *gs_imr;
}

void ee_gs_put_imr(u64 imr)
{
    *(volatile u64*)GS_IMR = imr;
    *gs_imr = imr;
}
