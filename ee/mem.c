// SPDX-License-Identifier: GPL-3.0-or-later

void* memcpy(void* dest, const void* src, unsigned int count)
{
    char* dest_ = (char*)dest;
    char* src_ = (char*)src;

    for (; count; count--) {
        *dest_ = *src_;
        dest_++;
        src_++;
    }
    return dest;
}

void* memset(void* dest, int ch, unsigned int count)
{
    unsigned char* dest_ = (unsigned char*)dest;
    unsigned char ch_ = (unsigned char)ch;

    for (; count; count--) {
        *dest_ = ch_;
        dest_++;
    }
    return dest;
}

int strlen(const char* string)
{
    if (string == 0) {
        return 0;
    }

    for (int count = 0; ; count++) {
        if (*string == '\0') {
            return count;
        }
        string++;
    }

    return 0;
}
