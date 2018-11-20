// SPDX-License-Identifier: GPL-3.0-or-later
#include "stdout.h"

void ee_start()
{
    __asm__ volatile("move $3, $0\n"
                "syscall\n"
                ::: "$3");

    while (1);
}
