#include "boot.h"

/*
 * 启动编排实现
 *
 * 原则：阶段严格串行（依赖不可跳），阶段内可并行（同 class 无依赖）。
 * 每阶段带超时，卡住时能直接定位到是哪一阶段，而不是干等。
 */

static const boot_stage_desc_t g_stages[] = {
    { BOOT_STAGE_KERNEL, "kernel",    5000  },
    { BOOT_STAGE_ROOTFS, "rootfs",    10000 },
    { BOOT_STAGE_INIT,   "init",      5000  },
    { BOOT_STAGE_DAEMON, "daemon",    20000 },  /* 已删隐私服务，仅剩最小集 */
    { BOOT_STAGE_SERVER, "sysserver", 60000 },  /* 最大单项，7.4 已标注     */
    { BOOT_STAGE_UI,     "ui",        15000 },
    { BOOT_STAGE_READY,  "ready",     1000  }
};

static boot_stage_t g_current = BOOT_STAGE_KERNEL;
static int g_ready = 0;

int guest_boot_advance(boot_stage_t stage)
{
    if (stage <= g_current || stage >= BOOT_STAGE_MAX)
        return -1;

    /* 依赖检查：不允许跳阶段 */
    if (stage != g_current + 1)
        return -1;

    g_current = stage;
    if (stage == BOOT_STAGE_READY)
        g_ready = 1;
    return 0;
}

boot_stage_t guest_boot_current(void)
{
    return g_current;
}

int guest_boot_wait_ready(int timeout_ms)
{
    /* 简化实现：真实环境应基于等待队列，此处返回当前是否就绪 */
    (void)timeout_ms;
    return g_ready ? 0 : -1;
}

int guest_boot_run(void)
{
    boot_stage_t s;

    /* 内核按序推进每个阶段；阶段内部由 init 按 class 并行拉起守护进程 */
    for (s = BOOT_STAGE_ROOTFS; s < BOOT_STAGE_MAX; s++) {
        if (guest_boot_advance(s) != 0)
            return -(int)s;   /* 返回失败阶段，便于定位 */
    }
    return 0;
}
