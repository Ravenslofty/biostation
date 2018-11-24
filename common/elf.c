// SPDX-License-Identifier: GPL-3.0-or-later

#include "types.h"

struct ElfHeader {
    unsigned char       e_ident[16];    // 0-15
    unsigned short      e_type;         // 16-17
    unsigned short      e_machine;      // 18-19
    unsigned int        e_version;      // 20-23
    void*               e_entry;        // 24-27
    unsigned int        e_phoff;        // 28-31
    unsigned int        e_shoff;        // 32-35
    unsigned int        e_flags;        // 36-39
    unsigned short      e_ehsize;       // 40-41
    unsigned short      e_phentsize;    // 42-43
    unsigned short      e_phnum;        // 44-45
    unsigned short      e_shentsum;     // 46-47
    unsigned short      e_shnum;        // 48-49
    unsigned short      e_shstrndx;     // 50-51
};

struct ElfProgramHeader {
    unsigned int        p_type;         // 0-3
    unsigned int        p_offset;       // 4-7
    unsigned int*       p_vaddr;        // 8-11
    unsigned int*       p_paddr;        // 12-15
    unsigned int        p_filesz;       // 16-19
    unsigned int        p_memsz;        // 20-23
    unsigned int        p_flags;        // 24-27
    unsigned int        p_align;        // 28-31
};

void* parse_elf(char* ELF_file)
{
    u32 e_ident = *(u32*)&ELF_file[0x00];
    u32 e_entry = *(u32*)&ELF_file[0x18];
    u32 e_phoff = *(u32*)&ELF_file[0x1C];
    u16 e_phnum = *(u16*)&ELF_file[0x2C];

    if (e_ident != 0x464C457F) {
        ee_kwrite("[!!] Invalid ELF header.\n");
        __asm__ volatile("break");
    }

    for (unsigned int i = e_phoff; i < e_phoff + (e_phnum * 0x20); i += 0x20) {
        u32 p_offset = *(u32*)&ELF_file[i + 0x4];
        u32 p_paddr = *(u32*)&ELF_file[i + 0xC];
        u32 p_filesz = *(u32*)&ELF_file[i + 0x10];

        int mem_w = p_paddr;
        for (unsigned int file_w = p_offset; file_w < (p_offset + p_filesz); file_w += 4) {
            u32 word = *(u32*)&ELF_file[file_w];
            *(u32*)mem_w = word;
            mem_w += 4;
        }
    }
    
    return (void*)e_entry;
}
