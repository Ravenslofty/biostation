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

void ee_tlb_write(u8 index, u32 vaddr, u32 paddr, u32 page_size, u8 cache_mode, bool scratchpad)
{
    u32 page_shift = 0;
    u32 page_mask = 0;

    u32 tmp = page_size >> 10;
    for (int i = 0; i < 5; i++) {
        tmp >>= 2;
        if (tmp) {
            page_shift += 2;
            page_mask = (page_mask << 2) | 3;
        }
    }       

    page_mask <<= 12;

    u32 vpn2 = ((vaddr / page_size) << page_shift) >> 1;
    u32 entry_hi = vpn2 << 13;
    u32 entry_lo1 = ((paddr >> 12) << 6) | ((cache_mode & 0x7) << 3) | 7; // Dirty, Valid, Global
    u32 entry_lo0 = entry_lo1 | (scratchpad << 31);

    asm volatile("mtc0 %0, $0" : : "r" (index));
    asm volatile("mtc0 %0, $2" : : "r" (entry_lo0));
    asm volatile("mtc0 %0, $3" : : "r" (entry_lo1));
    asm volatile("mtc0 %0, $5" : : "r" (page_mask));
    asm volatile("mtc0 %0, $10" : : "r" (entry_hi));
    asm volatile("sync.p; tlbwi; sync.p");
}

void ee_tlb_init()
{
    // Scratchpad RAM.
    ee_tlb_write( 0, 0x70000000, 0x00000000, 16*1024,      7, true);
    
    // Cached RDRAM.
    // First megabyte is unmapped to catch null-pointer exceptions.
    ee_tlb_write( 1, 0x00100000, 0x00100000, 16*1024*1024, 3, false);
    ee_tlb_write( 2, 0x01100000, 0x01100000, 4*1024*1024,  3, false);
    ee_tlb_write( 3, 0x01500000, 0x01500000, 4*1024*1024,  3, false);
    ee_tlb_write( 4, 0x01900000, 0x01900000, 4*1024*1024,  3, false);
    ee_tlb_write( 5, 0x01D00000, 0x01D00000, 1*1024*1024,  3, false);
    ee_tlb_write( 6, 0x01E00000, 0x01E00000, 1*1024*1024,  3, false);
    ee_tlb_write( 7, 0x01F00000, 0x01F00000, 1*1024*1024,  3, false);

    // Uncached RDRAM.
    ee_tlb_write( 8, 0x20100000, 0x00100000, 16*1024*1024, 2, false);
    ee_tlb_write( 9, 0x21100000, 0x01100000, 4*1024*1024,  2, false);
    ee_tlb_write(10, 0x21500000, 0x01500000, 4*1024*1024,  2, false);
    ee_tlb_write(11, 0x21900000, 0x01900000, 4*1024*1024,  2, false);
    ee_tlb_write(12, 0x21D00000, 0x01D00000, 1*1024*1024,  2, false);
    ee_tlb_write(13, 0x21E00000, 0x01E00000, 1*1024*1024,  2, false);
    ee_tlb_write(14, 0x21F00000, 0x01F00000, 1*1024*1024,  2, false);

    // Uncached, Accelerated RDRAM.
    ee_tlb_write(15, 0x30100000, 0x00100000, 16*1024*1024, 7, false);
    ee_tlb_write(16, 0x31100000, 0x01100000, 4*1024*1024,  7, false);
    ee_tlb_write(17, 0x31500000, 0x01500000, 4*1024*1024,  7, false);
    ee_tlb_write(18, 0x31900000, 0x01900000, 4*1024*1024,  7, false);
    ee_tlb_write(19, 0x31D00000, 0x01D00000, 1*1024*1024,  7, false);
    ee_tlb_write(20, 0x31E00000, 0x01E00000, 1*1024*1024,  7, false);
    ee_tlb_write(21, 0x31F00000, 0x01F00000, 1*1024*1024,  7, false);

    // EE memory-mapped I/O.
    ee_tlb_write(22, 0x10000000, 0x10000000, 64*1024,      2, false);

    // VU memory.
    ee_tlb_write(23, 0x11000000, 0x11000000, 64*1024,      2, false);

    // GS memory-mapped I/O.
    ee_tlb_write(24, 0x12000000, 0x12000000, 64*1024,      2, false);
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
