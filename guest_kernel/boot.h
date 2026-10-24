#ifndef VM_LITE_GUEST_BOOT_H
#define VM_LITE_GUEST_BOOT_H

/*
 * 启动编排：由 Guest 内核主导
 *
 * 内核起来后不是甩手给 init 就完事，而是自己驱动一条确定性启动链：
 *   内核 -> 挂载根 -> 拉 init -> 按 class 起守护 -> 起 system_server
 *   -> 起极简桌面 -> 就绪广播
 *
 * 每个阶段有明确依赖与超时，失败可定位到具体阶段。
 */

/* 启动阶段 */
typedef enum {
    BOOT_STAGE_KERNEL   = 0,   /* 内核自检、驱动初始化      */
    BOOT_STAGE_ROOTFS   = 1,   /* 挂载根文件系统            */
    BOOT_STAGE_INIT     = 2,   /* 拉起 init 进程            */
    BOOT_STAGE_DAEMON   = 3,   /* 守护进程（按 class 并行） */
    BOOT_STAGE_SERVER   = 4,   /* system_server 核心服务    */
    BOOT_STAGE_UI       = 5,   /* 极简桌面 + SystemUI       */
    BOOT_STAGE_READY    = 6,   /* 广播就绪，开放应用启动    */
    BOOT_STAGE_MAX
} boot_stage_t;

typedef struct {
    boot_stage_t stage;
    const char  *name;
    int          timeout_ms;   /* 单阶段超时，超时即报具体阶段 */
} boot_stage_desc_t;

/* 内核启动主入口：由内核 initcall 调用 */
int guest_boot_run(void);

/* 阶段推进与查询 */
int  guest_boot_advance(boot_stage_t stage);
boot_stage_t guest_boot_current(void);
int  guest_boot_wait_ready(int timeout_ms);

#endif /* VM_LITE_GUEST_BOOT_H */
