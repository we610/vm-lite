    .section .text
    .global mmu_enable
mmu_enable:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp

    tlbi    vmalle1is
    dsb     sy
    isb

    movz    x1, #0x0900, lsl #16
    mov     w0, #'m'
    str     w0, [x1]               /* m = 进入 */

    mrs     x0, sctlr_el1
    orr     x0, x0, #1
    msr     sctlr_el1, x0          /* ★ 开 MMU */
    isb

    movz    x1, #0x0900, lsl #16
    mov     w0, #'n'
    str     w0, [x1]               /* n = MMU 已开 */

    dsb     sy
    isb
    movz    x1, #0x0900, lsl #16
    mov     w0, #'o'
    str     w0, [x1]               /* o = 屏障完成 */

    ldp     x29, x30, [sp], #32
    ret
