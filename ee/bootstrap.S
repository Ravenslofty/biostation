// SPDX-License-Identifier: GPL-3.0-or-later
#include "locations.h"
#include "regdef.h"

.extern ee_start
.extern ee_init_main_thread

.extern memcpy

// The interrupt handler table sits at 0000'0300
#define interrupt_table_size    16 * 4

// The syscall table sits at 0000'0400
#define syscall_table_size      128 * 4

// Kernel stack pointer location.
#define stack_pointer           END_OF_KERNEL_RAM

.text
// EE assembly startup routine.
.global _ee_start
_ee_start:
        // Set up the system control coprocessor. This skips a lot of initialisation which is
        // meaningless to an emulator, but very important on physical hardware, like MMU init.
        li      t0, 0x70400000          // Coprocessors all usable, bootstrap exception vectors,
        mtc0    t0, Status              // interrupts disabled.
       
        // Mask interrupts from the EE interrupt controller.
        li      t0, EE_INTC_MASK
        sw      zero, 0(t0)

        // Now we can set up the C runtime; or enough of it for us, anyway.
        li      sp, END_OF_SCRATCH_RAM  // Set the stack pointer to the top of scratchpad RAM.
        
        // Copy the interrupt table.
        li      a0, INTERRUPT_TABLE
        la      a1, _handlers_start
        li      a2, interrupt_table_size
        jal     memcpy
        nop
        
        // Copy the syscall table.
        li      a0, SYSCALL_TABLE
        la      a1, _syscalls_start
        li      a2, syscall_table_size
        jal     memcpy
        nop

        // Set up the kernel stack pointer in $k1.
        la      k1, stack_pointer
        j       ee_start                // Jump to C.
        nop

// Preserve all registers except $k0, $k1 and $ra.
.global _save_context
_save_context:
        .set noat
        addi    k1, -448
        sq      at, 0(k1)
        sq      v0, 16(k1)
        sq      v1, 32(k1)
        sq      a0, 48(k1)
        sq      a1, 64(k1)
        sq      a2, 80(k1)
        sq      a3, 96(k1)
        sq      t0, 112(k1)
        sq      t1, 128(k1)
        sq      t2, 144(k1)
        sq      t3, 160(k1)
        sq      t4, 176(k1)
        sq      t5, 192(k1)
        sq      t6, 208(k1)
        sq      t7, 224(k1)
        sq      s0, 240(k1)
        sq      s1, 256(k1)
        sq      s2, 272(k1)
        sq      s3, 288(k1)
        sq      s4, 304(k1)
        sq      s5, 320(k1)
        sq      s6, 336(k1)
        sq      s7, 352(k1)
        sq      t8, 368(k1)
        sq      t9, 384(k1)
        sq      gp, 400(k1)
        sq      sp, 416(k1)
        sq      fp, 432(k1)
        j       ra
        nop
        .set at

// Restore all registers except $k0, $k1 and $ra.
.global _restore_context
_restore_context:
        .set noat
        lq      at, 0(k1)
        lq      v0, 16(k1)
        lq      v1, 32(k1)
        lq      a0, 48(k1)
        lq      a1, 64(k1)
        lq      a2, 80(k1)
        lq      a3, 96(k1)
        lq      t0, 112(k1)
        lq      t1, 128(k1)
        lq      t2, 144(k1)
        lq      t3, 160(k1)
        lq      t4, 176(k1)
        lq      t5, 192(k1)
        lq      t6, 208(k1)
        lq      t7, 224(k1)
        lq      s0, 240(k1)
        lq      s1, 256(k1)
        lq      s2, 272(k1)
        lq      s3, 288(k1)
        lq      s4, 304(k1)
        lq      s5, 320(k1)
        lq      s6, 336(k1)
        lq      s7, 352(k1)
        lq      t8, 368(k1)
        lq      t9, 384(k1)
        lq      gp, 400(k1)
        lq      sp, 416(k1)
        lq      fp, 432(k1)
        addi    k1, 448
        j       ra
        nop
        .set at

// Handle a System Call Exception.
// $3: syscall number
// $4...: args
_syscall_handler:
        addi    k1, -16                 // Save $ra to stack.
        sq      ra, 0(k1)
        
        la      k0, SYSCALL_TABLE       // Load the start of the syscall table.
        andi    $3, 0x7F                // Mask out the "sign" bit of the syscall.
        sll     $3, 2                   // Convert syscall number to index.
        addu    k0, $3                  // Calculate the syscall table offset.
        lw      k0, 0(k0)               // Find the handler address.

        jalr    k0                      // Jump to it.
        nop
        
        lq      ra, 0(k1)               // Restore $ra from stack.
        addi    k1, 16

        mfc0    k0, EPC                 // Increment EPC to run the next instruction.
        addi    k0, 4
        mtc0    k0, EPC
        
        sync                            // Memory synchronisation.
        eret                            // And return.

// FlushCache is irrelevant to an emulator, so we stub it.
_ee_flush_cache:
        jr      ra
        nop

// A syscall handler that crashes.
_unimplemented_syscall:
        srl     a0, $3, 2
        jal     ee_unimplemented_syscall
        nop
        break

// A syscall that says hello.
_hello:
        addi    k1, -48
        sq      a0, 0(k1)
        sq      a1, 16(k1)
        sq      ra, 32(k1)

        la      a0, _hello_string       // Load string address.
        jal     ee_kwrite
        nop

        lq      a0, 0(k1)
        lq      a1, 16(k1)
        lq      ra, 32(k1)
        addi    k1, 48
        
        j       ra
        nop

// Handle an interrupt.
.section .ee_exc_common, "a"
.global _ee_interrupt_handler
_ee_interrupt_handler:
        // First, save the relevant state.
        addi    k1, -16                 // Save $t0 to stack.
        sq      t0, 0(k1)
        
        // Then, examine the COP0 Cause register to find which interrupt we have.
        mfc0    k0, Cause
        andi    k0, 0x3F                // Extract Cause.ExcCode.
        la      t0, INTERRUPT_TABLE     // Load start of handler table
        add     k0, t0                  // Add ExcCode to handler table

        lq      t0, 0(k1)               // Restore $t0 from stack
        addi    k1, 16
        
        lw      k0, 0(k0)               // Get the handler address.
        jr      k0                      // Jump to the handler.
        nop

.data
_hello_string:
.asciz  "Hello, World!\n"

_handlers_start:
.int    _unimplemented_syscall  // 00: Interrupt.
.int    _unimplemented_syscall  // 01: TLB Modified.
.int    _unimplemented_syscall  // 02: TLB Refill (load)
.int    _unimplemented_syscall  // 03: TLB Refill (store)
.int    _unimplemented_syscall  // 04: Address error (load)
.int    _unimplemented_syscall  // 05: Address error (store)
.int    _unimplemented_syscall  // 06: Bus error (instruction)
.int    _unimplemented_syscall  // 07: Bus error (data)
.int    _syscall_handler        // 08: System call
.int    _unimplemented_syscall  // 09: Breakpoint
.int    _unimplemented_syscall  // 10: Reserved instruction
.int    _unimplemented_syscall  // 11: Coprocessor unusable
.int    _unimplemented_syscall  // 12: Overflow
.int    _unimplemented_syscall  // 13: Trap
.int    _unimplemented_syscall
.int    _unimplemented_syscall

_syscalls_start:
.int    _hello                  // 00h: Hello()
.int    _unimplemented_syscall  // 01h: ResetEE(int devices)
.int    ee_gs_set_crt           // 02h: SetGsCrt(bool interlaced, int display_mode, bool frame)
.int    _unimplemented_syscall
.int    _unimplemented_syscall  // 04h: Exit(int status)
.int    _unimplemented_syscall  // 05h: _ExceptionEpilogue()
.int    _unimplemented_syscall  // 06h: LoadExecPS2(const char* filename, int argc, char** argv)
.int    _unimplemented_syscall  // 07h: ExecPS2(void (*entry)(), void* gp, int argc, char** argv)
.int    _unimplemented_syscall 
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall  // 10h: AddIntcHandler(int int_cause, int (*handler)(), int next, void* arg, int flag)
.int    _unimplemented_syscall  // 11h: RemoveIntcHandler(int int_cause, int handler_id)
.int    _unimplemented_syscall  // 12h: AddDmacHandler(int dmac_cause, int (*handler)(), int next, void* arg, int flag)
.int    _unimplemented_syscall  // 13h: RemoveDmacHandler(int dmac_cause, int handler_id)
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall  // 20h: CreateThread(ThreadParam* t)
.int    _unimplemented_syscall  // 21h: DeleteThread(int thread_id)
.int    _unimplemented_syscall  // 22h: ExitThread()
.int    _unimplemented_syscall  // 23h: ExitDeleteThread()
.int    _unimplemented_syscall  // 24h: TerminateThread(int thread_id)
.int    _unimplemented_syscall  // 25h: iTerminateThread(int thread_id)
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall  // 29h: ChangeThreadPriority(int thread_id, int priority)
.int    _unimplemented_syscall  // 2Ah: iChangeThreadPriority(int thread_id, int priority)
.int    _unimplemented_syscall  // 2Bh: RotateThreadReadyQueue(int priority)
.int    _unimplemented_syscall  // 2Ch: _iRotateThreadReadQueue(int priority)
.int    _unimplemented_syscall  // 2Dh: void ReleaseWaitThread(int thread_id)
.int    _unimplemented_syscall  // 2Eh: int iReleaseWaitThread(int thread_id)
.int    _unimplemented_syscall  // 2Fh: int GetThreadId()
.int    _unimplemented_syscall  // 30h: int ReferThreadStatus(int thread_id, ThreadParam* status)
.int    _unimplemented_syscall  // 31h: int iReferThreadStatus(int thread_id, ThreadParam* status)
.int    _unimplemented_syscall  // 32h: void SleepThread()
.int    _unimplemented_syscall  // 33h: void WakeupThread(int thread_id)
.int    _unimplemented_syscall  // 34h: int iWakeupThread(int thread_id)
.int    _unimplemented_syscall  // 35h: int CancelWakeupThread(int thread_id)
.int    _unimplemented_syscall  // 36h: int iCancelWakeupThread(int thread_id)
.int    _unimplemented_syscall  // 37h: int SuspendThread(int thread_id)
.int    _unimplemented_syscall  // 38h: int iSuspendThread(int thread_id)
.int    _unimplemented_syscall  // 39h: void ResumeThread(int thread_id)
.int    _unimplemented_syscall  // 3Ah: int iResumeThread(int thread_id)
.int    _unimplemented_syscall  // 3Bh: void JoinThread()
.int    ee_init_main_thread     // 3Ch: void* InitMainThread(u32 gp, void* stack, i32 stack_size, char* args, u32 return_address)
.int    ee_init_heap            // 3Dh: void* InitHeap(void* heap_bottom, i32 heap_size)
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall  // 40h
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall  // 50h
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall  // 60h
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _ee_flush_cache         // 64h: FlushCache(i32 mode)
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    ee_gs_get_imr           // 70h: u64 GsGetIMR()
.int    ee_gs_put_imr           // 71h: void GsPutIMR(u64 imr)
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
.int    _unimplemented_syscall
