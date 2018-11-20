// SPDX-License-Identifier: GPL-3.0-or-later
#include "regdef.h"

.extern	_ee_start
.extern _iop_start

.section ".common_start"
// BIOS startup for both EE and IOP.
// Because this is targeting emulators, we don't have to do nearly as much as the PS2 BIOS does.
.global _start
_start:
	mfc0	t0, PRid		// Get processor version.
	li	t1, 0x59
	bge	t0, t1, _found_ee	// If this is the EE: jump to its specific loader.
	nop
	j	_iop_start		// Otherwise, jump to the IOP.
	nop
_found_ee:
	j	_ee_start		// Trampoline to get around the EE startup routine being undefined.
	nop

