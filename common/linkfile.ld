/* SPDX-License-Identifier: GPL-3.0-or-later */

ENTRY(_start);

SECTIONS {
    .text 0x1fc00000: {
        KEEP(*(.common_start));

        /* Put the EE common interrupt handler at 0x1fc0'0380 */
        . = 0x380;
        KEEP(*(.ee_int_common));

        /*. = 0x1fc00480;*/
        *(.text .text.*);
    }

    .data : {
        *(.rodata .rodata.*);
        *(.data .data.*);
    }

    .bss : {
        *(.bss .bss.*);
    }
}
