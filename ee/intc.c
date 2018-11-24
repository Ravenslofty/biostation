// SPDX-License-Identifier: GPL-3.0-or-later

#include "locations.h"
#include "types.h"

// *quietly judges Sony for using a linked list*
struct LinkedList {
    struct LinkedList* next;
    struct LinkedList* prev;
};

struct Handler {
    int (*func)(int);
    u32 gp;
    void* arg;
    bool in_use;
};

// Handle an interrupt from the interrupt controller.
void ee_intc_handler()
{
    /* STUB */
}

// Enable an interrupt from the interrupt controller, returning whether the interrupt mask was updated.
bool ee_enable_intc(int cause_bit)
{
    int mask = *(volatile int*)EE_INTC_MASK;

    if (mask & (1 << cause_bit)) {
        return false;
    } else {
        mask |= 1 << cause_bit;
        *(volatile int*)EE_INTC_MASK = mask;
    }
    
    return true;
}

int ee_add_intc_handler(int cause, int (*handler)(int), int next, void* arg, int flag)
{
    /* STUB: needed for pillgen */
    return -1;
}
