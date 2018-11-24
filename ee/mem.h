// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef MEM_H
#define MEM_H

extern void* memcpy(void* dest, const void* src, unsigned int count);
extern void* memset(void* dest, int ch, unsigned int count);

extern int strlen(const char* str);

#endif // MEM_H
