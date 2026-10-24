/*
 * ARM32 裸机入口
 *
 * QEMU virt 把内核镜像加载到 0x40000000 并直接跳到这里，
 * 此时没有栈、没有 libc、没有 MMU。这里只做两件事：
 *   1. 建立栈
 *   2. 跳进 kernel_main (C 世界)
 *
 * kernel_main 返回后（不应发生）进入 wfi 死循环。
 */

    .section .text.startup
    .global _start

_start:
    /* 关中断，裸机阶段不接任何 IRQ */
    cpsid   if

    /* 建立栈：link.ld 中 __stack_top 预留了 64KB */
    ldr     sp, =__stack_top

    /* 清 bss 段（.bss 里放的是 g_current / g_ready 等全局变量） */
    ldr     r0, =__bss_start
    ldr     r1, =__bss_end
    mov     r2, #0
1:
    cmp     r0, r1
    bge     2f
    str     r2, [r0], #4
    b       1b
2:
    bl      kernel_main

    /* 不应返回；返回则停机 */
3:
    wfi
    b       3b
