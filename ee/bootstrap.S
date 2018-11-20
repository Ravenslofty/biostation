// SPDX-License-Identifier: GPL-3.0-or-later
#include "regdef.h"

.extern ee_start

#define end_of_ram		0x00100000

// The syscall table sits at the end of kernel RAM.
#define syscall_table_size	128 * 4
#define syscall_table		end_of_ram - syscall_table_size

// Kernel stack pointer location.
#define stack_pointer		end_of_ram - syscall_table_size

.text
// EE assembly startup routine.
.global _ee_start
_ee_start:
	// Set up the system control coprocessor. This skips a lot of initialisation which is
	// meaningless to an emulator, but very important on physical hardware, like MMU init.
	li	t0, 0x70400000		// Coprocessors all usable, bootstrap exception vectors,
	mtc0	t0, Status		// interrupts disabled.
	// Set up the syscall table through a simple memcpy loop.
	la	t0, syscall_table	// Load the RAM syscall table location.
	la	t1, end_of_ram		// Load the end of RAM as an end location.
	la	t2, _syscalls_start	// Load the ROM syscall table location.
1:					// This loop is padded to avoid the short loop bug.
	lq	t3, 0(t2)		// Grab a handful of stuff...
	sq	t3, 0(t0)		// and dump it somewhere else.
	lq	t3, 16(t2)		
	sq	t3, 16(t0)		
	addi	t0, 32			// Bump the pointers...
	addi	t2, 32		
	bne	t0, t1, 1b		// If we haven't reached the end of RAM, continue.
	nop
	// Set up the kernel stack pointer in $k0.
	la	k1, stack_pointer
	// Now we can set up the C runtime; or enough of it for us, anyway.
	li	sp, 0x70004000		// Set the stack pointer to the top of scratchpad RAM.
	j	ee_start		// Jump to C.
	nop

// Preserve all registers except $k0, $k1 and $ra.
.global _save_context
_save_context:
	.set noat
	addi	k1, -448
	sq	at, 0(k1)
	sq	v0, 16(k1)
	sq	v1, 32(k1)
	sq	a0, 48(k1)
	sq	a1, 64(k1)
	sq	a2, 80(k1)
	sq	a3, 96(k1)
	sq	t0, 112(k1)
	sq	t1, 128(k1)
	sq	t2, 144(k1)
	sq	t3, 160(k1)
	sq	t4, 176(k1)
	sq	t5, 192(k1)
	sq	t6, 208(k1)
	sq	t7, 224(k1)
	sq	s0, 240(k1)
	sq	s1, 256(k1)
	sq	s2, 272(k1)
	sq	s3, 288(k1)
	sq	s4, 304(k1)
	sq	s5, 320(k1)
	sq	s6, 336(k1)
	sq	s7, 352(k1)
	sq	t8, 368(k1)
	sq	t9, 384(k1)
	sq	gp, 400(k1)
	sq	sp, 416(k1)
	sq	fp, 432(k1)
	j	ra
	nop
	.set at

// Restore all registers except $k0, $k1 and $ra.
.global _restore_context
_restore_context:
	.set noat
	lq	at, 0(k1)
	lq	v0, 16(k1)
	lq	v1, 32(k1)
	lq	a0, 48(k1)
	lq	a1, 64(k1)
	lq	a2, 80(k1)
	lq	a3, 96(k1)
	lq	t0, 112(k1)
	lq	t1, 128(k1)
	lq	t2, 144(k1)
	lq	t3, 160(k1)
	lq	t4, 176(k1)
	lq	t5, 192(k1)
	lq	t6, 208(k1)
	lq	t7, 224(k1)
	lq	s0, 240(k1)
	lq	s1, 256(k1)
	lq	s2, 272(k1)
	lq	s3, 288(k1)
	lq	s4, 304(k1)
	lq	s5, 320(k1)
	lq	s6, 336(k1)
	lq	s7, 352(k1)
	lq	t8, 368(k1)
	lq	t9, 384(k1)
	lq	gp, 400(k1)
	lq	sp, 416(k1)
	lq	fp, 432(k1)
	addi	k1, 448
	j	ra
	nop
	.set at

// Handle a System Call Exception.
// $3: syscall number
// $4...: args
_syscall_handler:
	la	k0, syscall_table	// Load the start of the syscall table.
	andi	$3, 0x7F		// Mask out the "sign" bit of the syscall.
	sll	$3, 2			// Convert syscall number to index.
	addu	$3, k0			// Calculate the syscall table offset.
	lw	$3, 0(k0)		// Find the handler address.
	jalr	$3			// Jump to it.
	nop
	mfc0	k0, EPC			// Increment EPC to run the next instruction.
	addi	k0, 4
	mtc0	k0, EPC
	sync				// Memory synchronisation.
	eret				// And return.

// A syscall handler that crashes.
_unimplemented_syscall:
	break

// A syscall that says hello.
_hello:
	li	t0, 0x1000F180		// Load EE debug stdout address.
	la	t1, _hello_string	// Load string address.
1:
	lbu	t2, 0(t1)		// memcpy loop.
	sb	t2, 0(t0)
	addi	t1, 1
	nop
	nop
	bne	t2, zero, 1b
	nop
	j	ra

// Handle an interrupt.
.section .ee_int_common, "a"
.global _interrupt_handler
_interrupt_handler:
	// First, save the relevant state.
	addi	k1, -16			// Save $t0 to stack.
	sq	t0, 0(k1)
	// Then, examine the COP0 Cause register to find which interrupt we have.
	mfc0	k0, Cause
	andi	k0, 0x3F		// Extract Cause.ExcCode.
	la	t0, _handlers_start	// Load start of handler table
	add	k0, t0
	lq	t0, 0(k1)		// Restore $t0 from stack
	addi	k1, 16
	lw	k0, 0(k0)		// Get the handler address.
	jr	k0			// Jump to the handler.
	nop

.data
.align	8
_hello_string:
.asciz	"Hello, World!\n"

.align	8
_handlers_start:
.int	_unimplemented_syscall	// 00: Interrupt.
.int	_unimplemented_syscall	// 01: TLB Modified.
.int	_unimplemented_syscall	// 02: TLB Refill (load)
.int	_unimplemented_syscall	// 03: TLB Refill (store)
.int	_unimplemented_syscall	// 04: Address error (load)
.int	_unimplemented_syscall	// 05: Address error (store)
.int	_unimplemented_syscall	// 06: Bus error (instruction)
.int	_unimplemented_syscall	// 07: Bus error (data)
.int	_syscall_handler	// 08: System call
.int	_unimplemented_syscall	// 09: Breakpoint
.int	_unimplemented_syscall	// 10: Reserved instruction
.int	_unimplemented_syscall	// 11: Coprocessor unusable
.int	_unimplemented_syscall	// 12: Overflow
.int	_unimplemented_syscall	// 13: Trap
.int	_unimplemented_syscall	// Unused
.int	_unimplemented_syscall	// Unused

.align 	8

_syscalls_start:
.int	_hello			// 00: Hello()
.int	_unimplemented_syscall 	// 01: ResetEE(int devices)
.int	_unimplemented_syscall 	// 02: SetGsCrt(bool interlaced, int display_mode, bool frame)
.int	_unimplemented_syscall
.int	_unimplemented_syscall 	// 04: Exit(int status)
.int	_unimplemented_syscall 	// 05: _ExceptionEpilogue()
.int	_unimplemented_syscall 	// 06: LoadExecPS2(const char* filename, int argc, char** argv)
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
.int	_unimplemented_syscall
_syscalls_end:
