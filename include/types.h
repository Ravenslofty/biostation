// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TYPES_H
#define TYPES_H

typedef _Bool bool;
typedef unsigned char u8;
typedef unsigned short u16;
typedef signed short i16;
typedef unsigned int u32;
typedef signed int i32;
typedef unsigned int u64;
typedef unsigned int u128 __attribute__(( mode(TI) ));

#define false 0
#define true 1

#endif // TYPES_H
