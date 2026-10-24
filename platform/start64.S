/*
 * AArch64 裸机入口（ARM64 / ARMv8-A）
 *
 * QEMU virt 把内核镜像加载到 0x40000000 并直接跳到这里。
 * AArch64 下 QEMU 默认从 EL1 开始（后面要接 EL2 时加
 * -machine virt,virtualization=on 即可，无需改这里）。
 *
 * 与 32 位版职责相同：
 *   1. 建立栈
 *   2. 清 bss
 *   3. 跳进 kernel_main (C 世界)
 */

    .section .text.startup
    .global _start

_start:
    /* 建立栈：link.ld 中 __stack_top 预留了 64KB */
    ldr     x30, =__stack_top
    mov     sp, x30

    /* 清 bss（g_current / g_ready 等全局变量都在这里） */
    ldr     x0, =__bss_start
    ldr     x1, =__bss_end
    mov     x2, #0
1:
    cmp     x0, x1
    b.ge    2f
    str     x2, [x0], #8
    b       1b
2:
    bl      kernel_main

    /* 不应返回；返回则停机 */
3:
    wfi
    b       3b
