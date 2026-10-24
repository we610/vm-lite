#include <stdint.h>
#include "uart.h"
#include "boot.h"

/*
 * vm-lite guest 内核入口（C 世界）
 *
 * 这里只做一件事：驱动 guest_boot_run() 那条七阶段启动链，
 * 并把每个阶段的结果从串口打出来。
 *
 * 注意：boot.c 里的阶段推进是严格串行的（不可跳阶段），
 * 所以这里能逐阶段观察到推进过程——这正是我们要在 QEMU 里验证的东西。
 */

static const char *stage_name(int s)
{
    switch (s) {
    case BOOT_STAGE_KERNEL: return "kernel";
    case BOOT_STAGE_ROOTFS: return "rootfs";
    case BOOT_STAGE_INIT:   return "init";
    case BOOT_STAGE_DAEMON: return "daemon";
    case BOOT_STAGE_SERVER: return "sysserver";
    case BOOT_STAGE_UI:     return "ui";
    case BOOT_STAGE_READY:  return "ready";
    default:                return "unknown";
    }
}

void kernel_main(void)
{
    int r;
    int s;

    uart_puts("\n");
    uart_puts("========================================\n");
    uart_puts("  vm-lite  guest kernel  (ARM32 bare)   \n");
    uart_puts("========================================\n");
    uart_puts("[boot] current stage: ");
    uart_puts(stage_name((int)guest_boot_current()));
    uart_puts("\n");

    /* 驱动七阶段启动链 */
    r = guest_boot_run();

    if (r != 0) {
        uart_puts("[boot] FAILED at stage ");
        uart_puts(stage_name(-r));
        uart_puts("\n");
        return;
    }

    uart_puts("[boot] stage chain OK, final = ");
    uart_puts(stage_name((int)guest_boot_current()));
    uart_puts("\n");

    /* 逐阶段打印一遍，确认没有跳阶段 */
    for (s = BOOT_STAGE_KERNEL; s < BOOT_STAGE_MAX; s++) {
        uart_puts("  stage[");
        uart_putc('0' + s);
        uart_puts("] = ");
        uart_puts(stage_name(s));
        uart_puts("\n");
    }

    if (guest_boot_wait_ready(1000) == 0)
        uart_puts("[boot] READY broadcast\n");
    else
        uart_puts("[boot] not ready\n");

    uart_puts("[boot] done. halt.\n");
}
