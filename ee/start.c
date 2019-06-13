// SPDX-License-Identifier: GPL-3.0-or-later
#include "elf.h"
#include "romdir.h"
#include "stdout.h"
#include "types.h"

extern int* _current_thread;

void ee_unimplemented_syscall(char id)
{
    char c[16] = "0123456789ABCDEF";
    char s[2] = { c[id >> 4], c[id & 0xF] };

    ee_kwrite("[EE] Unimplemented syscall ");
    ee_kwrite(s);
    ee_kwrite("h\n");
    ee_kwrite("[EE] Team Rocket is blasting off again!\n");

    asm volatile("break");
}

// Initialise the EE kernel.
void ee_start()
{
    ee_kwrite("[EE] ee_start: Checking syscall handling\n");
    
    // Produce a friendly hello on the debug console, but also check that the syscall handler is 
    // working.
    asm volatile("move $3, $0\n"
                "syscall\n"
                ::: "$3");

    ee_kwrite("[EE] ee_start: Syscall handling seems OK\n");

    // Initialise the current thread.
    *_current_thread = 0;

    // Load the ELF; at the moment just from a hardcoded address.
    ee_kwrite("[EE] ee_start: Looking up ELF\n");
    
    int addr = romdir_lookup("PILLGEN");
    
    ee_kwrite("[EE] ee_start: Found ELF at $");

    char number[8] = {0};

    for (int digit = 7; digit >= 0; digit--) {
        const char hexdigits[16] = "0123456789ABCDEF";
        int hex = (addr >> (digit * 4)) & 0xF;
        number[7-digit] = hexdigits[hex];
    }

    ee_kwrite(number);
    ee_kwrite("\n");

    void (*func)() = parse_elf((const char*)addr);

    if (func != 0) {
        ee_kwrite("[EE] ee_start: It's showtime!\n");
        func();
    } else {
        ee_kwrite("[EE] ee_start: ELF load returned a null pointer.\n");
    }
    
    asm volatile("break");
}
