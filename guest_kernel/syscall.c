#include "syscall.h"
#include "isolation.h"

/*
 * Guest 内核 syscall 分发实现
 *
 * 关键：这里处理的是 Guest 自己的 syscall。
 * 只有当处理函数需要触碰真实硬件时，才调用 guest_exit_to_vmm。
 * 除此之外的一切都在 Guest 内核内部完成，主内核完全不知情。
 */

#define GUEST_SYSCALL_MAX 64

static guest_syscall_handler_t g_table[GUEST_SYSCALL_MAX];

int guest_syscall_register(uint64_t nr, guest_syscall_handler_t fn)
{
    if (nr >= GUEST_SYSCALL_MAX || !fn)
        return -1;
    g_table[nr] = fn;
    return 0;
}

int guest_syscall_dispatch(guest_syscall_ctx_t *ctx)
{
    if (!ctx || ctx->nr >= GUEST_SYSCALL_MAX)
        return -1;

    /* 未注册：留在 Guest 内核内部返回错误，不穿透到宿主 */
    if (!g_table[ctx->nr])
        return -1;

    return g_table[ctx->nr](ctx);
}

/*
 * 设备读写示例：
 * Guest 用户态 syscall 进来 -> Guest 内核驱动 ->
 * 访问设备寄存器触发 MMIO -> Stage-2 fault -> VM exit 到 VMM
 *
 * 注意：MMIO 触发的 exit 是硬件自动完成的（Stage-2 缺页），
 * 不需要在这里显式调用 guest_exit_to_vmm。
 * 显式调用仅用于 hypercall 这类 Guest 主动请求。
 */
int guest_hw_ioctl_stub(guest_syscall_ctx_t *ctx)
{
    /* 走 hwif 层，hwif 内部对真实/虚拟后端透明 */
    (void)ctx;
    return 0;
}
