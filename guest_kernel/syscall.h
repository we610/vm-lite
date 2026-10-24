#ifndef VM_LITE_GUEST_SYSCALL_H
#define VM_LITE_GUEST_SYSCALL_H

/*
 * Guest 内核系统调用表 —— 与主内核（宿主内核）完全独立
 *
 * 隔离要点：
 *   1. Guest 内核拥有独立的 syscall 表、独立的地址空间、独立的进程管理
 *   2. Guest 用户态发起 svc 指令，陷入的是 Guest 内核自己的 EL1，
 *      不会、也不应该穿透到宿主内核
 *   3. 只有当 Guest 内核需要触碰真实资源时，才通过 VM exit 落到 VMM
 */

#include <stdint.h>

/* Guest 私有 syscall 号 —— 编号与宿主内核无关，独立编排 */
typedef enum {
    SYS_GUEST_HW_OPEN   = 1000,
    SYS_GUEST_HW_READ   = 1001,
    SYS_GUEST_HW_WRITE  = 1002,
    SYS_GUEST_HW_IOCTL  = 1003,
    SYS_GUEST_HW_MMAP   = 1004,
    SYS_GUEST_HW_IRQ_WAIT = 1005,
    SYS_GUEST_MAX
} guest_syscall_nr_t;

/* syscall 上下文：由陷入 EL1 时的寄存器快照填充 */
typedef struct {
    uint64_t nr;
    uint64_t arg0;
    uint64_t arg1;
    uint64_t arg2;
    uint64_t arg3;
    uint64_t ret;
} guest_syscall_ctx_t;

/* 分发入口：Guest 内核 EL1 侧调用 */
int guest_syscall_dispatch(guest_syscall_ctx_t *ctx);

/* 注册处理函数 */
typedef int (*guest_syscall_handler_t)(guest_syscall_ctx_t *ctx);
int guest_syscall_register(uint64_t nr, guest_syscall_handler_t fn);

#endif /* VM_LITE_GUEST_SYSCALL_H */
