ENTRY(_start);

SECTIONS {
    .text 0x1fc00000: {
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
