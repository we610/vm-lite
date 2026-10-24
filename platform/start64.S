    .section .text.startup
    .global _start
_start:
    ldr     x30, =__stack_top
    mov     sp, x30

    ldr     x0, =__bss_start
    ldr     x1, =__bss_end
    mov     x2, #0
1:  cmp     x0, x1
    b.ge    2f
    str     x2, [x0], #8
    b       1b
2:
    /* MMU 已移除：不建页表、不开 SCTLR.M */

    ldr     x0, =vectors
    msr     vbar_el1, x0
    isb

    bl      kernel_main
3:  wfi
    b       3b
