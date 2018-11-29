// SPDX-License-Identifier: GPL-3.0-or-later

#include "types.h"

struct ElfHeader {
    u8      e_ident[16];    // 0-15
    u16     e_type;         // 16-17
    u16     e_machine;      // 18-19
    u32     e_version;      // 20-23
    void*   e_entry;        // 24-27
    u32     e_phoff;        // 28-31
    u32     e_shoff;        // 32-35
    u32     e_flags;        // 36-39
    u16     e_ehsize;       // 40-41
    u16     e_phentsize;    // 42-43
    u16     e_phnum;        // 44-45
    u16     e_shentsum;     // 46-47
    u16     e_shnum;        // 48-49
    u16     e_shstrndx;     // 50-51
};

struct ElfProgramHeader {
    u32     p_type;         // 0-3
    u32     p_offset;       // 4-7
    u32*    p_vaddr;        // 8-11
    u32*    p_paddr;        // 12-15
    u32     p_filesz;       // 16-19
    u32     p_memsz;        // 20-23
    u32     p_flags;        // 24-27
    u32     p_align;        // 28-31
};

struct ElfSectionHeader {
    u32     sh_name;
    u32     sh_type;
    u32     sh_flags;
    void*   sh_addr;
    u32     sh_offset;
    u32     sh_size;
    u32     sh_link;
    u32     sh_info;
    u32     sh_addralign;
    u32     sh_entsize;
};

void* parse_elf(char* ELF_file)
{
    u32 e_ident = *(u32*)&ELF_file[0x00];
    u32 e_entry = *(u32*)&ELF_file[0x18];
    u32 e_phoff = *(u32*)&ELF_file[0x1C];
    u16 e_phnum = *(u16*)&ELF_file[0x2C];

    if (e_ident != 0x464C457F) {
        ee_kwrite("[!!] Invalid ELF header.\n");
        asm volatile("break");
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
