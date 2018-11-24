// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef THREAD_H
#define THREAD_H

#include "types.h"

// Register state for a thread.
struct ThreadContext {
    u128 gprs[25]; // $at - $t9
    u128 gp, fp, sp, ra, hi, lo;
    u32  sa;
    u32  fprs[32]; // $f0 - $f31
    u32  fp_acc;
    u32  fp_ctrl;
};

// A thread.
struct Thread {
    // The thread's $gp register.
    u32   gp_reg;
    // Size of the thread's stack.
    i32   stack_size;
    // The top of the thread's stack, minus space for a ThreadContext.
    void* initial_stack;
    // The bottom of the thread's stack.
    void* stack_bottom;
    // The top of the thread's heap.
    void* heap_top;
    // The address to return to after the thread exits.
    void* return_address;
    // Thread arguments.
    char* args;
};

#endif // THREAD_H
