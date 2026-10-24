/*
 * vm-lite guest 内核链接脚本
 *
 * QEMU virt (ARM32) 的 RAM 起始地址是 0x40000000，
 * -kernel 会把镜像加载到这里并从 _start 开始执行。
 */

ENTRY(_start)

SECTIONS
{
    . = 0x40000000;

    .text : {
        *(.text.startup)
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data*)
    }

    __bss_start = .;
    .bss : {
        *(.bss*)
        *(COMMON)
    }
    __bss_end = .;

    . = ALIGN(16);
    . += 0x10000;          /* 预留 64KB 栈 */
    __stack_top = .;

    /DISCARD/ : {
        *(.note*)
        *(.comment*)
        *(.ARM.attributes)
    }
}
