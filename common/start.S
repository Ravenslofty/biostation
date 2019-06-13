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
        j       _iop

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
        li      k0, (\mask << 13)
        mtc0    k0, PageMask
.endm

.macro TLB_WRITE
        sync.p
        tlbwi
        sync.p
.endm

_ee:
        // Map EE memory using the TLB.
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
        TLB_ENTRY_LO1   4, 0, 1, 1, 1
        TLB_ENTRY_HI    0x38000, 0
        TLB_PAGE_MASK   3
        TLB_WRITE

        // Set up the C runtime; or enough of it for us, anyway.
        li      sp, 0x70004000          // Set the stack pointer to the top of scratchpad RAM.

        // Fully map the EE memory space.
        jal     ee_tlb_init

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
