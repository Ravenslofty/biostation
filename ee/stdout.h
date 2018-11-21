// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef STDOUT_H
#define STDOUT_H

void ee_kwrite(const void* buf, unsigned int count);
void ee_kprintf(const char* fmt, ...);

#endif // STDOUT_H
