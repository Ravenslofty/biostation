// SPDX-License-Identifier: GPL-3.0-or-later
#include "regdef.h"

.extern	_ee_start
.extern _iop_start

.section ".common_start"
// BIOS startup for both EE and IOP.
// Because this is targeting emulators, we don't have to do nearly as much as the PS2 BIOS does.
.global _start
_start:
	lui	sp, 0x0020		// Set the stack pointer to a memory location common to both chips.

	mfc0	t0, PRid		// Get processor version.
	li	t1, 0x59
	bge	t0, t1, _found_ee	// If this is the EE: jump to its specific loader.
	j	_iop			// Otherwise, jump to the IOP.	
_found_ee:
	j	_ee

.text
_iop:
	la	a0, _detected_iop	// Show signs of life.
	jal	iop_kwrite

	la	a0, _iop_kernel_name	// Search for LOADCORE
	jal	romdir_lookup		// in the ROM directory.

	addi	sp, -16
	sw	v0, 0(sp)

	la	a0, _found_loadcore
	jal	iop_kwrite

	lw	a0, 0(sp)
	jal	parse_elf		// IRX is based on ELF, so we'll load it as if it was an ELF.

	sw	v0, 0(sp)

	la	a0, _loaded_loadcore
	jal	iop_kwrite

	lw	v0, 0(sp)
	jr	v0

_ee:
	la	a0, _detected_ee	// Show signs of life.
	jal	ee_kwrite

	la	a0, _ee_kernel_name	// EE kernel name.
	jal	romdir_lookup		// Find the EE kernel in ROM.
	
	addi	sp, -16
	sw	v0, 0(sp)

	la	a0, _found_eekern	// Parsing the ELF could fail, at which point we would
	jal	ee_kwrite		// crash after printing this.

	lw	a0, 0(sp)
	jal	parse_elf		// Load the kernel from ROM into RAM.
	sw	v0, 0(sp)

	la	a0, _loaded_eekern	// If EEKERNEL is correct but the entry point is wrong,
	jal	ee_kwrite		// then we will hang here, giving a good clue.

	lw	v0, 0(sp)
	jr	v0			// Jump to the entry point.

.data

_detected_ee:
.asciz	"[COM] _start: Detected EE\n"
_found_eekern:
.asciz	"[COM] _start: Found EEKERNEL in ROMDIR\n"
_loaded_eekern:
.asciz	"[COM] _start: Loaded EEKERNEL into RAM\n"

_detected_iop:
.asciz	"[COM] _start: Detected IOP\n"
_found_loadcore:
.asciz	"[COM] _start: Found LOADCORE in ROMDIR\n"
_loaded_loadcore:
.asciz	"[COM] _start: Loaded LOADCORE into RAM\n"

// EEKERNEL isn't in the real BIOS, but we use it because the ELF format is convenient.
_ee_kernel_name:
.asciz	"EEKERNEL"

_iop_kernel_name:
.asciz	"LOADCORE"
