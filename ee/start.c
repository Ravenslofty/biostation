#include "stdout.h"

void ee_start()
{
    const char str[14] = "Hello, World!\n";
    ee_kwrite(str, 14);

    while (1);
}
