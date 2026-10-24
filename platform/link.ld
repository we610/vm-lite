ENTRY(_start)

SECTIONS
{
    . = 0x40000000;

    .text : {
        *(.text.startup)
        . = ALIGN(2048);
        *(.text.vectors)
        *(.text*)
    }

    .rodata : { *(.rodata*) }
    .data   : { *(.data*) }

    __bss_start = .;
    .bss : { *(.bss*) *(COMMON) }
    __bss_end = .;

    . = ALIGN(4096);
    __ttbr0_l1 = .;
    . += 4096;

    . = ALIGN(16);
    . += 0x10000;
    __stack_top = .;

    . = ALIGN(16);
    . += 0x8000;
    __el0_stack_top = .;

    /DISCARD/ : { *(.note*) *(.comment*) *(.ARM.attributes) }
}
