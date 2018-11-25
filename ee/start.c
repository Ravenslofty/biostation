// SPDX-License-Identifier: GPL-3.0-or-later
#include "elf.h"
#include "stdout.h"

extern int* _current_thread;

void ee_unimplemented_syscall(char id)
{
    char c[16] = "0123456789ABCDEF";
    char s[2] = { c[id >> 4], c[id & 0xF] };

    ee_kwrite("[!!] Unimplemented syscall ");
    ee_kwrite(s);
    ee_kwrite("h\n");
    ee_kwrite("[!!] Team Rocket is blasting off again!\n");
}

// Initialise the EE kernel.
void ee_start()
{
    // Produce a friendly hello on the debug console, but also check that the syscall handler is 
    // working.
    __asm__ volatile("move $3, $0\n"
                "syscall\n"
                ::: "$3");

    // Initialise the current thread.
    *_current_thread = 0;

    // Load the ELF; at the moment just from a hardcoded address.
    ee_kwrite("Loading ELF\n");
    
    void (*func)() = parse_elf((const char*)0x1fc04000);

    if (func != 0) {
        ee_kwrite("Load OK.\n");
        func();
    } else {
        ee_kwrite("Load returned a null pointer.\n");
    }
    
    __asm__ volatile("break");
}
