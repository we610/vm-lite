    .section .text
    .global mmu_enable
mmu_enable:
    mrs     x0, sctlr_el1
    orr     x0, x0, #1          /* M  : 开 MMU */
    orr     x0, x0, #4          /* C  : data cache */
    orr     x0, x0, #0x1000     /* I  : instr cache */
    msr     sctlr_el1, x0
    dsb     sy
    isb
    ret
