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
.global _start
_start:
        // Set up the C runtime; or enough of it for us, anyway.
        li      sp, END_OF_SCRATCH_RAM  // Set the stack pointer to the top of scratchpad RAM.

        // Announce our presence to the debugger on the other end of the screen.
        la      a0, _load_ok
        jal     ee_kwrite

        // Set up the system control coprocessor. This skips a lot of initialisation which is
        // meaningless to an emulator, but very important on physical hardware, like MMU init.
        li      t0, 0x70000000          // Coprocessors all usable, normal exception vectors,
        mtc0    t0, Status              // interrupts disabled.
       
        // Mask interrupts from the EE interrupt controller.
        li      t0, EE_INTC_MASK
        sw      zero, 0(t0)

        // Mask interrupts from the DMA controller.
        li      t0, EE_DMAC_STAT
        lui     t1, 0x63FF              // Mask channels 0 - 9, stall interrupt and MFIFO empty interrupt.
        lw      t2, 0(t0)
        and     t2, t1
        sw      t2, 0(t0)

        la      a0, _interrupts_off
        jal     ee_kwrite

        // Zero the .bss section.
        la      a0, _start_of_bss
        la      a1, 0
        la      a2, _end_of_bss
        sub     a2, a0
        jal     memset

        // Re-enable interrupts.
        li      t0, 0x70008C01          // Coprocessors all usable, normal exception vectors,
        mtc0    t0, Status              // interrupts enabled.

        la      a0, _interrupts_on
        jal     ee_kwrite

        // Set up the kernel stack pointer in $k1.
        la      k1, stack_pointer
        j       ee_start                // Jump to C.

// Preserve all registers except $k0, $k1 and $ra.
.global _save_context
_save_context:
        .set noat
        addi    sp, -496
        sq      at, 0(sp)
        sq      v0, 16(sp)
        sq      v1, 32(sp)
        sq      a0, 48(sp)
        sq      a1, 64(sp)
        sq      a2, 80(sp)
        sq      a3, 96(sp)
        sq      t0, 112(sp)
        sq      t1, 128(sp)
        sq      t2, 144(sp)
        sq      t3, 160(sp)
        sq      t4, 176(sp)
        sq      t5, 192(sp)
        sq      t6, 208(sp)
        sq      t7, 224(sp)
        sq      s0, 240(sp)
        sq      s1, 256(sp)
        sq      s2, 272(sp)
        sq      s3, 288(sp)
        sq      s4, 304(sp)
        sq      s5, 320(sp)
        sq      s6, 336(sp)
        sq      s7, 352(sp)
        sq      t8, 368(sp)
        sq      t9, 384(sp)
        sq      gp, 400(sp)
        sq      sp, 416(sp)
        sq      fp, 432(sp)
        mflo    t0
        mflo1   t1
        mfhi    t2
        mfhi1   t3
        mfsa    t4
        sd      t0, 448(sp)
        sd      t1, 456(sp)
        sd      t2, 464(sp)
        sd      t3, 472(sp)
        sw      t4, 480(sp)
        j       ra
        .set at

// Restore all registers except $k0, $k1 and $ra.
.global _restore_context
_restore_context:
        .set noat
        ld      t0, 448(sp)
        ld      t1, 456(sp)
        ld      t2, 464(sp)
        ld      t3, 472(sp)
        lw      t4, 480(sp)
        mtlo    t0
        mtlo1   t1
        mthi    t2
        mthi1   t3
        mtsa    t4
        lq      at, 0(sp)
        lq      v0, 16(sp)
        lq      v1, 32(sp)
        lq      a0, 48(sp)
        lq      a1, 64(sp)
        lq      a2, 80(sp)
        lq      a3, 96(sp)
        lq      t0, 112(sp)
        lq      t1, 128(sp)
        lq      t2, 144(sp)
        lq      t3, 160(sp)
        lq      t4, 176(sp)
        lq      t5, 192(sp)
        lq      t6, 208(sp)
        lq      t7, 224(sp)
        lq      s0, 240(sp)
        lq      s1, 256(sp)
        lq      s2, 272(sp)
        lq      s3, 288(sp)
        lq      s4, 304(sp)
        lq      s5, 320(sp)
        lq      s6, 336(sp)
        lq      s7, 352(sp)
        lq      t8, 368(sp)
        lq      t9, 384(sp)
        lq      gp, 400(sp)
        lq      sp, 416(sp)
        lq      fp, 432(sp)
        addi    sp, 496
        j       ra
        .set at

// Handle a System Call Exception.
// $3: syscall number
// $4...: args
_syscall_handler:
        addi    k1, -16                 // Save $ra to stack.
        sq      ra, 0(k1)
        
        la      k0, _syscalls_start     // Load the start of the syscall table.
        andi    $3, 0x7F                // Mask out the "sign" bit of the syscall.
        sll     $3, 2                   // Convert syscall number to index.
        addu    k0, $3                  // Calculate the syscall table offset.
        lw      k0, 0(k0)               // Find the handler address.

        jalr    k0                      // Jump to it.
        
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

// A syscall handler that crashes.
_unimplemented_syscall:
        srl     a0, $3, 2
        jal     ee_unimplemented_syscall
        break

// A syscall that says hello.
_hello:
        addi    k1, -48
        sq      a0, 0(k1)
        sq      a1, 16(k1)
        sq      ra, 32(k1)

        la      a0, _hello_string       // Load string address.
        jal     ee_kwrite

        lq      a0, 0(k1)
        lq      a1, 16(k1)
        lq      ra, 32(k1)
        addi    k1, 48
        
        j       ra

// Handle an interrupt from the DMA controller.
_ee_dmac_handler:
        break

// Handle an interrupt from the timer.
_ee_timer_handler:
        break

// Interrupt handler in .text to avoid size restrictions.
_ee_interrupt_handler_big:
        // Examine the COP0 Cause register to find which interrupt we have.
        // Is this from the interrupt controller?
        mfc0    k0, Cause
        andi    k0, 1 << 10             // Cause.IP2 - Interrupt controller.
        beq     k0, zero, 1f
        
        la      k0, ee_intc_handler
        j       4f
1:
        // Is this from the DMA controller?
        mfc0    k0, Cause
        andi    k0, 1 << 11             // Cause.IP3 - DMA controller
        beq     k0, zero, 2f

        la      k0, _ee_dmac_handler
        j       4f
2:
        // Is this from the timer?
        mfc0    k0, Cause
        andi    k0, 1 << 15             // Cause.IP7 - Timer
        beq     k0, zero, 3f

        la      k0, _ee_timer_handler
        j       4f
3:
        // We have an unrecognised interrupt which indicates a bug somewhere; break.
        break
4:
        // Save ra and sp
        addi    k1, -32
        sq      ra, 0(k1)
        sq      sp, 16(k1)

        move    sp, k1

        // Jump to handler.
        jalr    k0

        // Restore ra and sp
        lq      ra, 0(k1)
        lq      sp, 16(k1)
        addi    k1, 32

        sync
        eret

// Handle a common exception.
.section .ee_exc_common, "a"
.global _ee_common_handler
_ee_common_handler:
        // First, save the relevant state.
        addi    k1, -16                 // Save $t0 to stack.
        sq      t0, 0(k1)
        
        // Then, examine the COP0 Cause register to find which interrupt we have.
        mfc0    k0, Cause
        andi    k0, 0x3F                // Extract Cause.ExcCode.
        la      t0, _handlers_start     // Load start of handler table
        add     k0, t0                  // Add ExcCode to handler table

        lq      t0, 0(k1)               // Restore $t0 from stack
        addi    k1, 16
        
        lw      k0, 0(k0)               // Get the handler address.
        jr      k0                      // Jump to the handler.

.section .ee_exc_interrupt, "a"
.global _ee_interrupt_handler
_ee_interrupt_handler:
        j       _ee_interrupt_handler_big

.data
_load_ok:
.asciz  "[EE] _start: Load OK\n"
.align

_interrupts_off:
.asciz  "[EE] _start: Interrupts disabled\n"
.align

_interrupts_on:
.asciz  "[EE] _start: Interrupts enabled\n"
.align

_hello_string:
.asciz  "Hello, World!\n"
.align

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
.int    ee_add_intc_handler     // 10h: AddIntcHandler(int int_cause, int (*handler)(), int next, void* arg, int flag)
.int    _unimplemented_syscall  // 11h: RemoveIntcHandler(int int_cause, int handler_id)
.int    _unimplemented_syscall  // 12h: AddDmacHandler(int dmac_cause, int (*handler)(), int next, void* arg, int flag)
.int    _unimplemented_syscall  // 13h: RemoveDmacHandler(int dmac_cause, int handler_id)
.int    ee_enable_intc          // 14h: _EnableIntc(int cause_bit)
.int    ee_disable_intc         // 15h: _DisableIntc(int cause_bit)
.int    ee_enable_dmac          // 16h: _EnableDmac(int cause_bit)
.int    ee_disable_dmac         // 17h: _DisableDmac(int cause_bit)
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
