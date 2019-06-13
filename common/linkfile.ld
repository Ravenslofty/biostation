/* SPDX-License-Identifier: GPL-3.0-or-later */

ENTRY(_start);

SECTIONS {
    .text 0xbfc00000 : {
        KEEP(*(.common_start));

        . = 0x100;
        KEEP(*(.iop_exc_tlbmiss));

        . = 0x180;
        KEEP(*(.iop_exc_common));

        . = 0x200;
        KEEP(*(.ee_exc_tlbmiss));

        . = 0x280;
        KEEP(*(.ee_exc_counter));

        . = 0x300;
        KEEP(*(.ee_exc_debug));

        . = 0x380;
        KEEP(*(.ee_exc_common));

        . = 0x400;
        KEEP(*(.ee_exc_interrupt));

        . = 0x480;
        *(.text .text.*);
    }

    .data : {
        *(.rodata .rodata.*);
        *(.data .data.*);
    }

    .bss : {
        *(.bss .bss.*);
    }

    end = .;
}
