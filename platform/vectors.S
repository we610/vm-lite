    .section .text.vectors
    .global vectors
    .global userland_done

    .balign 2048
vectors:
    b el1_panic ; .align 7      /* 0x000 cur EL SP0 sync   */
    b el1_panic ; .align 7      /* 0x080 irq               */
    b el1_panic ; .align 7      /* 0x100 fiq               */
    b el1_panic ; .align 7      /* 0x180 serror            */
    b el1_panic ; .align 7      /* 0x200 cur EL SPx sync   */
    b el1_panic ; .align 7      /* 0x280 irq               */
    b el1_panic ; .align 7      /* 0x300 fiq               */
    b el1_panic ; .align 7      /* 0x380 serror            */
    b el0_sync_entry ; .align 7 /* 0x400 lower EL64 sync ★*/
    b el1_panic ; .align 7      /* 0x480 irq               */
    b el1_panic ; .align 7      /* 0x500 fiq               */
    b el1_panic ; .align 7      /* 0x580 serror            */
    b el1_panic ; .align 7      /* 0x600 lower EL32 sync   */
    b el1_panic ; .align 7      /* 0x680 irq               */
    b el1_panic ; .align 7      /* 0x700 fiq               */
    b el1_panic ; .align 7      /* 0x780 serror            */

/* ===== EL1 意外异常：打印后停机 ===== */
el1_panic:
    bl      el1_panic_c
1:  wfi
    b       1b

/* ===== EL0 陷入 EL1（svc / abort 都从这里进） ===== */
el0_sync_entry:
    stp x0, x1,   [sp, #-16]!
    stp x2, x3,   [sp, #-16]!
    stp x4, x5,   [sp, #-16]!
    stp x6, x7,   [sp, #-16]!
    stp x8, x9,   [sp, #-16]!
    stp x10, x11, [sp, #-16]!
    stp x12, x13, [sp, #-16]!
    stp x14, x15, [sp, #-16]!
    stp x16, x17, [sp, #-16]!
    stp x18, x19, [sp, #-16]!
    stp x20, x21, [sp, #-16]!
    stp x22, x23, [sp, #-16]!
    stp x24, x25, [sp, #-16]!
    stp x26, x27, [sp, #-16]!
    stp x28, x29, [sp, #-16]!
    str x30,      [sp, #-16]!
    mrs x0, esr_el1
    mrs x1, elr_el1
    stp x0, x1,   [sp, #-16]!
    mrs x2, spsr_el1
    mrs x3, sp_el0
    stp x2, x3,   [sp, #-16]!

    mov x0, sp
    bl  el0_sync_handler       /* C 里可改 tf[ELR] 决定去向 */

    ldp x2, x3,   [sp, #272]
    ldp x0, x1,   [sp, #256]
    msr elr_el1,  x1
    msr spsr_el1, x2

    ldp x0, x1,   [sp, #0]
    ldp x2, x3,   [sp, #16]
    ldp x4, x5,   [sp, #32]
    ldp x6, x7,   [sp, #48]
    ldp x8, x9,   [sp, #64]
    ldp x10, x11, [sp, #80]
    ldp x12, x13, [sp, #96]
    ldp x14, x15, [sp, #112]
    ldp x16, x17, [sp, #128]
    ldp x18, x19, [sp, #144]
    ldp x20, x21, [sp,#160]
    ldp x22, x23, [sp, #176]
    ldp x24, x25, [sp, #192]
    ldp x26, x27, [sp, #208]
    ldp x28, x29, [sp, #224]
    ldr x30,      [sp, #240]
    add sp, sp, #288
    eret

/* ===== 降特权级到 EL0 ===== */
    .global enter_usermode
enter_usermode:                 /* x0=entry, x1=user sp */
    str     x30, [sp, #-16]!    /* 保存返回地址 */
    msr     sp_el0, x1
    msr     elr_el1, x0
    mov     x2, #0              /* SPSR=0 → M=0000 (EL0t) */
    msr     spsr_el1, x2
    eret

/* ===== 用户程序结束 / 被终止后回到这里 ===== */
userland_done:
    ldr     x30, [sp], #16
    b       userland_done_c
