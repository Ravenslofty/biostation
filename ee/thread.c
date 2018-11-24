// SPDX-License-Identifier: GPL-3.0-or-later

#include "locations.h"
#include "mem.h"
#include "thread.h"
#include "types.h"

// The thread state. 
#define END_OF_RAM   0x02000000

struct Thread* threads = (struct Thread*)THREAD_ARRAY;
int* _current_thread = (int*)CURR_THREAD;
#define current_thread threads[*_current_thread]

// Initialise the main thread, setting up the stack and returning it.
void* ee_init_main_thread(u32 gp, void* stack_ptr, i32 stack_size, char* args, u32 return_address)
{
    // -1 is a magic term meaning "the end of RAM", more or less.
    // I don't think games care too much about the exact positioning, but we'll follow the BIOS.
    if ((i32)stack_ptr == -1) {
        // Specifically, -1 means "the end of RAM minus (stack_size plus 4KiB)".
        stack_ptr = (void*)(END_OF_RAM - (stack_size + 4096));
    }

    // Initialise a thread context within the 4KiB buffer zone.
    struct ThreadContext* ctx = (struct ThreadContext*)((u32)stack_ptr + stack_size - sizeof(struct ThreadContext) / 4);

    ctx->gp = gp;
    ctx->ra = return_address;
    ctx->fp = ctx->sp = (u32)ctx + sizeof(struct ThreadContext);

    // Zero the thread array.
    memset(threads, 0, 256 * sizeof(struct Thread));

    // Initialise the current thread.
    current_thread.gp_reg = gp;
    current_thread.stack_size = stack_size;
    current_thread.initial_stack = ctx;
    current_thread.stack_bottom = stack_ptr;
    current_thread.return_address = (void*)return_address;
    // TODO: setup argument buffer from args.

    // Return the ThreadContext object that represents this thread.
    return ctx;
}

// Initialise the heap, returning the top of the heap.
void* ee_init_heap(void* heap_bottom, i32 heap_size)
{
    if (heap_size < 0) {
        current_thread.heap_top = current_thread.stack_bottom;
    } else {
        current_thread.heap_top = (void*)((u32)heap_bottom + (u32)heap_size);
    }

    return current_thread.heap_top;
}
