// SPDX-License-Identifier: GPL-3.0-or-later
#include "regdef.h"

.extern iop_start

.text
// IOP start routine.
.global _iop_start
_iop_start:
					// We currently don't know where to put the IOP stack pointer.
	j	iop_start
	nop
