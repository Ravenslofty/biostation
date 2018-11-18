#include "regdef.h"

.extern	ee_start
.extern iop_start

.text
// BIOS startup for both EE and IOP.
// Because this is targeting emulators, we don't have to do nearly as much as the PS2 BIOS does.
.global _start
_start:
	mfc0	t0, PRid		// Get processor version.
	li	t1, 0x59
	blt	t0, t1, _iop_start	// If this is the IOP: jump to its specific loader.
	nop				
					// As a sanity check for any budding emulator devs,
	bge	t0, t1, _ee_start	// check the EE PRid field is correct.
	nop
_bad_prid:
					// If that's wrong too, somebody messed up their COP0
	add	sp, zero, zero		// implementation.
	ori	sp, 0x5052		// 'PR'
	sll	sp, 16
	ori	sp, 0x6964		// 'id'
	break				// Just so somebody gets the message.
_ee_start:
	li	sp, 0x70004000		// Set the stack pointer to the top of scratchpad RAM.
	j	ee_start		// Jump to C.
	nop
_iop_start:
					// We currently don't know where to put the IOP stack pointer.
	j	iop_start
	nop
	break
