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

.macro TLB_INDEX index
        li      k0, \index
        mtc0    k0, Index
.endm

.macro TLB_ENTRY_LO0 is_scratch, pfn, cache_mode, dirty, valid, global
        li      k0, (\is_scratch << 31) + (\pfn << 6) + (\cache_mode << 3) + (\dirty << 2) + (\valid << 1) + \global
        mtc0    k0, EntryLo0
.endm

.macro TLB_ENTRY_LO1 pfn, cache_mode, dirty, valid, global
        li      k0, (\pfn << 6) + (\cache_mode << 3) + (\dirty << 2) + (\valid << 1) + \global
        mtc0    k0, EntryLo1
.endm

.macro TLB_ENTRY_HI vpn2, asid
        li      k0, (\vpn2 << 13) + \asid
        mtc0    k0, EntryHi
.endm

.macro TLB_PAGE_MASK mask
        li      k0, \mask
        mtc0    k0, PageMask
.endm

.macro TLB_WRITE
        sync.p
        tlbwi
        sync.p
.endm

.text
// EE assembly startup routine.
.global _start
.ent _start
_start:
        // Map PS2 memory using the TLB.
        // Mark everything as invalid (for now)
        TLB_ENTRY_LO0   0, 0, 0, 0, 0, 0
        TLB_ENTRY_LO1   0, 0, 0, 0, 0
        TLB_ENTRY_HI    0, 0

        li              t0, 47
1:
        mtc0            t0, Index
        TLB_WRITE
        addiu           t0, -1
        bnez            t0, 1b

        // Scratchpad: 16KiB from scratch address 0 to 0x4000
        TLB_INDEX       0
        TLB_ENTRY_LO0   1, 0, 0, 1, 1, 1
        TLB_ENTRY_LO1   0, 0, 1, 1, 1
        TLB_ENTRY_HI    0x38000, 0
        TLB_PAGE_MASK   0
        TLB_WRITE

        // Set up the C runtime; or enough of it for us, anyway.
        li      sp, END_OF_SCRATCH_RAM  // Set the stack pointer to the top of scratchpad RAM.

        // Announce our presence to the debugger on the other end of the screen.
        la      a0, _load_ok
        jal     ee_kwrite

        // Set up the system control coprocessor. This skips a lot of initialisation which is
        // meaningless to an emulator, but very important on physical hardware, like MMU init.
        li      t0, 0x70000000          // Coprocessors all usable, normal exception vectors,
        mtc0    t0, Status              // interrupts disabled.
       
        // Fully initialise the TLB from C.
        // This is an incredibly awful workaround for as not understanding MIPS memory segmentation.
        //jal     ee_tlb_init

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
.end _start

// Preserve all registers except $k0, $k1 and $ra.
.global _save_context
_save_context:
        .set noat
        addi    sp, -496
        sq      $at, 0(sp)
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
        lq      $at, 0(sp)
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
        addiu   k1, 16

        mfc0    k0, EPC                 // Increment EPC to run the next instruction.
        addiu   k0, 4
        mtc0    k0, EPC
        
        sync                            // Memory synchronisation.
        eret                            // And return.

// FlushCache is irrelevant to an emulator, so we stub it.
_ee_flush_cache:
        jr      ra

// An exception handler that crashes.
_unimplemented_exception:

        mfc0    k0, Cause
        andi    k0, 0x3F                // Extract Cause.ExcCode.
        la      k1, _exception_strings_start
        addu    a0, k0, k1
        jal     ee_kwrite
        j       _start
1:      j       1b

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
.asciz  "[EE] _start: TLB set up, interrupts disabled\n"
.align

_interrupts_on:
.asciz  "[EE] _start: Interrupts enabled\n"
.align

_hello_string:
.asciz  "[EE] Hello, World!\n"
.align

_interrupt:
.asciz "Interrupt\n"
_tlb_modified:
.asciz "TLB Modified\n"
_tlb_miss_load:
.asciz "TLB Miss (load)\n"
_tlb_miss_store:
.asciz "TLB Miss (store)\n"
_address_error_load:
.asciz "Address Error (load)\n"
_address_error_store:
.asciz "Address Error (store)\n"
_bus_error_instruction:
.asciz "Bus Error (instruction)\n"
_bus_error_data:
.asciz "Bus Error (data)\n"
_system_call:
.asciz "System Call\n"
_breakpoint:
.asciz "Breakpoint\n"
_reserved_instruction:
.asciz "Reserved Instruction\n"
_coprocessor_unusable:
.asciz "Coprocessor Unusable\n"
_overflow:
.asciz "Overflow\n"
_trap:
.asciz "Trap\n"
_exception_14:
.asciz "Unknown exception 14\n"
_exception_15:
.asciz "Unknown exception 15\n"

_exception_strings_start:
.int    _interrupt
.int    _tlb_modified
.int    _tlb_miss_load
.int    _tlb_miss_store
.int    _address_error_load
.int    _address_error_store
.int    _bus_error_instruction
.int    _bus_error_data
.int    _system_call
.int    _breakpoint
.int    _reserved_instruction
.int    _coprocessor_unusable
.int    _overflow
.int    _trap
.int    _exception_14
.int    _exception_15

_handlers_start:
.int    _ee_interrupt_handler     // 00: Interrupt.
.int    _unimplemented_exception  // 01: TLB Modified.
.int    _unimplemented_exception  // 02: TLB Miss (load)
.int    _unimplemented_exception  // 03: TLB Miss (store)
.int    _unimplemented_exception  // 04: Address error (load)
.int    _unimplemented_exception  // 05: Address error (store)
.int    _unimplemented_exception  // 06: Bus error (instruction)
.int    _unimplemented_exception  // 07: Bus error (data)
.int    _syscall_handler          // 08: System call
.int    _unimplemented_exception  // 09: Breakpoint
.int    _unimplemented_exception  // 10: Reserved instruction
.int    _unimplemented_exception  // 11: Coprocessor unusable
.int    _unimplemented_exception  // 12: Overflow
.int    _unimplemented_exception  // 13: Trap
.int    _unimplemented_exception
.int    _unimplemented_exception

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
