// SPDX-License-Identifier: GPL-3.0-or-later

#define EE_DEBUG_OUT_ADDR 0x1000F180
#define DEBUG_BUF_MAX_LEN 80

#define va_list __builtin_va_list
#define va_start(list, arg) __builtin_stdarg_start((list), (arg))
#define va_arg __builtin_va_arg
#define va_end __builtin_va_end

#define TO_HEX(x, caps) (x <= 9 ? '0' + x : (caps ? 'A' : 'a') - 10 + x)

void ee_kwrite(const char* buf, unsigned int count)
{
    volatile char* const ee_debug_out = (volatile char* const) EE_DEBUG_OUT_ADDR;

    for (unsigned int i = 0; i < count; i++) {
        *ee_debug_out = buf[i];
    }
}

static inline void write_padding(int chars_to_write, int precision, int fill,
        char padding_char)
{
    volatile char* const ee_debug_out = (volatile char* const) EE_DEBUG_OUT_ADDR;
    if (chars_to_write > precision)
        chars_to_write = precision;
    int padding = fill - chars_to_write;
    while (padding > 0) {
        *ee_debug_out = padding_char;
        --padding;
    }
}

static inline int count_num_hex_digits(unsigned int num)
{
    if (!num)
        return 1;

    int count = 0;
    for (; num; num >>= 4)
        ++count;
    return count;
}

static inline int count_num_digits(int num)
{
    if (!num)
        return 1;

    int count = 0;
    for (; num; num /= 10)
        ++count;
    return count;
}

static void write_hex_number(unsigned int num, int upper)
{
    volatile char* const ee_debug_out = (volatile char* const) EE_DEBUG_OUT_ADDR;

    static const char hex_lookup_lower[] = "0123456789abcdef";
    static const char hex_lookup_upper[] = "0123456789ABCDEF";

    if (num < 0x10) {
        *ee_debug_out = upper ? hex_lookup_upper[num] : hex_lookup_lower[num];
    }
    else {
        unsigned int ls4b = num & 0xf;
        write_hex_number(num >> 4, upper);
        *ee_debug_out = upper ? hex_lookup_upper[ls4b] : hex_lookup_lower[ls4b];
    }
}

static void write_number(int num)
{
    volatile char* const ee_debug_out = (volatile char* const) EE_DEBUG_OUT_ADDR;

    if (num < 10) {
        *ee_debug_out = (char)(num + '0');
    }
    else {
        int lsd = num % 10;
        write_number(num / 10);
        *ee_debug_out = (char)(lsd + '0');
    }
}

static void write_arg(const char** curr_ptr, va_list* arg_list)
{
    volatile char* const ee_debug_out = (volatile char* const) EE_DEBUG_OUT_ADDR;

    // Early exit for "%%"
    if (**curr_ptr == '%') {
        *ee_debug_out = '%';
        ++*curr_ptr;
        return;
    }

    // Flags field
    char padding_char = ' ';
    switch (**curr_ptr) {
        case '-':
            // TODO: Implement
            ++*curr_ptr;
            break;
        case '+':
            // TODO: Implement
            ++*curr_ptr;
            break;
        case ' ':
            // TODO: Implement
            ++*curr_ptr;
            break;
        case '0':
            padding_char = '0';
            ++*curr_ptr;
            break;
        case '#':
            // TODO: Implement
            ++*curr_ptr;
            break;
    }

    // Width field
    unsigned int fill = 0;
    char curr_char = **curr_ptr;
    if (curr_char == '*') {
        fill = va_arg(*arg_list, unsigned int);
        ++*curr_ptr;
    }
    else {
        while (curr_char >= '0' && curr_char <= '9') {
            fill = fill * 10 + (curr_char - '0');
            curr_char = *++*curr_ptr;
        }
    }

    // Precision field
    unsigned int precision = DEBUG_BUF_MAX_LEN;
    curr_char = **curr_ptr;
    if (curr_char == '.') {
        curr_char = *++*curr_ptr;
        if (curr_char == '*') {
            precision = va_arg(*arg_list, unsigned int);
            ++*curr_ptr;
        }
        else {
            while (curr_char >= '0' && curr_char <= '9') {
                precision = precision * 10 + (curr_char - '0');
                curr_char = *++*curr_ptr;
            }
        }
    }

    // Cannot fill more bytes than precision
    if (fill > precision)
        fill = precision;

    // Length field
    // TODO: Implement

    // Type field
    // "%%" already handled
    curr_char = **curr_ptr;
    unsigned int padding;
    switch (curr_char) {
        case 'd':
        case 'i':
            ;
            int arg = va_arg(*arg_list, int);
            if (arg < 0) {
                *ee_debug_out = '-';
                arg = -arg;
            }
            write_padding(count_num_digits(arg), precision, fill, padding_char);
            write_number(arg);
            break;
        case 'u':
            ;
            unsigned int u_arg = va_arg(*arg_list, unsigned int);
            write_padding(count_num_digits(u_arg), precision, fill, padding_char);
            write_number(u_arg);
            break;
        case 'x':
        case 'X':
            ;
            unsigned int x = va_arg(*arg_list, unsigned int);
            int hex_len = count_num_hex_digits(x);
            write_padding(hex_len, precision, fill, padding_char);
            write_hex_number(x, curr_char == 'X');
            break;
        case 'c':
            write_padding(1, precision, fill, padding_char);
            *ee_debug_out = (char) va_arg(*arg_list, int);
            break;
        default:
            *ee_debug_out = curr_char;
            break;
    }

    ++*curr_ptr;
}

void ee_kprintf(char* fmt, ...)
{
    volatile char* const ee_debug_out = (volatile char* const) EE_DEBUG_OUT_ADDR;

    va_list list;
    va_start(list, fmt);
    const char* curr = fmt;
    while (*curr) {
        while (*curr == '%') {
            ++curr;
            write_arg(&curr, &list);
        }
        *ee_debug_out = *curr;
        ++curr;
    }
    va_end(list);
}
