// SPDX-License-Identifier: GPL-3.0-or-later

#include "locations.h"
#include "stdout.h"
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
    int cause;
};

#define HANDLER_ARRAY_SIZE 96
struct Handler* handlers = (struct Handler*)HANDLER_ARRAY;

void _save_context();
void _restore_context();

// Handle an interrupt from the interrupt controller.
void ee_intc_handler()
{
    _save_context();

    // Get the active interrupt mask.
    u32 stat = *(volatile u32*)EE_INTC_STAT;
    u32 mask = *(volatile u32*)EE_INTC_MASK;

    stat &= mask;

    // Find the highest priority (lowest bit) interrupt.
    for (int bit = 0; bit < 15; bit++) {
        if (stat & (1 << bit)) {
            // We have the interrupt, now loop through the handler array to find handlers for it.
            int start = bit * 6;
            int end = ((bit + 1) * 6) - 1;

            for (int i = start; i < end; i++) {
                if (handlers[i].func != 0 && handlers[i].cause == bit) {

                    ee_kwrite("Calling INTC handler\n");

                    // Swap the global pointers.
                    u32 new_gp = handlers[i].gp;
                    u32 old_gp;
                    asm volatile(
                        "move %0, $gp\n"
                        "move $gp, %1\n"
                        : "=r" (old_gp)
                        : "r" (new_gp)
                    );

                    // Call the callback.
                    handlers[i].func(bit);

                    // Swap the global pointers.
                    asm volatile(
                        "move %0, $gp\n"
                        "move $gp, %1\n"
                        : "=r" (new_gp)
                        : "r" (old_gp)
                    );

                    ee_kwrite("Returned from INTC handler\n");
                }
            }

            // Acknowledge the interrupt.
            *(volatile u32*)EE_INTC_STAT = 1 << bit;

            // Need to work out if this is needed.
            //break;
        }
    }

    _restore_context();
}

// Enable an interrupt from the interrupt controller, returning whether the interrupt mask was updated.
bool ee_enable_intc(int cause_bit)
{
    int mask = *(volatile int*)EE_INTC_MASK;

    if (mask & (1 << cause_bit)) {
        return false;
    } else {
        mask = 1 << cause_bit;
        *(volatile int*)EE_INTC_MASK = mask;
    }
    
    return true;
}

// Disable an interrupt from the interrupt controller, returning whether the interrupt mask was updated.
bool ee_disable_intc(int cause_bit)
{
    int mask = *(volatile int*)EE_INTC_MASK;

    if (mask & (1 << cause_bit)) {
        mask = 1 << cause_bit;
        *(volatile int*)EE_INTC_MASK = mask;
    } else {
        return false;
    }
    
    return true;
}

// Enable an interrupt from the DMA controller, returning whether the interrupt mask was updated.
bool ee_enable_dmac(int cause_bit)
{
    int mask = *(volatile int*)EE_DMAC_STAT;

    cause_bit += 16;

    if (mask & (1 << cause_bit)) {
        return false;
    } else {
        mask = 1 << cause_bit;
        *(volatile int*)EE_DMAC_STAT = mask;
    }
    
    return true;
}

// Disable an interrupt from the interrupt controller, returning whether the interrupt mask was updated.
bool ee_disable_dmac(int cause_bit)
{
    int mask = *(volatile int*)EE_DMAC_STAT;

    cause_bit += 16;

    if (mask & (1 << cause_bit)) {
        mask = 1 << cause_bit;
        *(volatile int*)EE_DMAC_STAT = mask;
    } else {
        return false;
    }
    
    return true;
}

// Add a callback function to the interrupt controller array.
int ee_add_intc_handler(int cause, int (*handler_func)(int), int next, void* arg, int flag)
{
    if (next > 0) {
        ee_kwrite("[!!] ee_add_intc_handler: next > 0");
        asm("break");
    }

    int start = cause * 6;
    int end = ((cause + 1) * 6) - 1;
    int slot = start;

    // If next == 0, put this at the closest free slot to the front.
    if (next == 0) {
        for (; slot <= end; slot++) {
            if (handlers[slot].func == 0) {
                break;
            }
        }

        if (slot > end) {
            ee_kwrite("[!!] ee_add_intc_handler: no more room in queue");
            asm("break");
        }
    }

    // If next == -1, put this at the end.
    if (next == -1) {
        slot = end;
        for (; slot >= start; slot--) {
            if (handlers[slot].func == 0) {
                break;
            }
        }

        if (slot < start) {
            ee_kwrite("[!!] ee_add_intc_handler: no more room in queue");
            asm("break");
        }
    }

    // Retrieve the global pointer.
    u32 gp;
    asm("move %0, $gp" : "=r" (gp));

    handlers[slot].func = handler_func;
    handlers[slot].gp = gp;
    handlers[slot].arg = arg;
    handlers[slot].cause = cause;

    return slot;
}
