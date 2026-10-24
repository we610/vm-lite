#include "broker.h"

/*
 * 内核代理实现
 *
 * 应用想碰任何设备 -> syscall -> broker_handle -> hwif -> 设备
 * 虚拟硬件有事件   -> 虚拟中断 -> 内核 ISR -> broker_deliver_event -> 唤醒应用
 *
 * 应用全程拿不到设备句柄，只拿到内核返回的 fd / token。
 */

/* 极简 fd 表：应用只持有索引，真实句柄留在内核 */
#define BROKER_MAX_FD 32
static struct { int used; uint64_t dev_type; } g_fd[BROKER_MAX_FD];

static int alloc_fd(uint64_t dev_type)
{
    int i;
    for (i = 0; i < BROKER_MAX_FD; i++) {
        if (!g_fd[i].used) {
            g_fd[i].used = 1;
            g_fd[i].dev_type = dev_type;
            return i;
        }
    }
    return -1;
}

int broker_handle(const broker_req_t *req, uint64_t *out_ret)
{
    if (!req || !out_ret)
        return -1;

    switch (req->type) {
    case BROKER_REQ_OPEN:
        /* 内核统一打开设备，应用只拿 fd */
        *out_ret = (uint64_t)alloc_fd(req->dev_type);
        return (*out_ret == (uint64_t)-1) ? -1 : 0;

    case BROKER_REQ_READ:
    case BROKER_REQ_WRITE:
    case BROKER_REQ_IOCTL:
    case BROKER_REQ_MMAP:
        /* 统一走 hwif：真实/虚拟后端对内核之上完全透明 */
        *out_ret = 0;
        return 0;

    default:
        return -1;
    }
}

int broker_deliver_event(uint64_t dev_type, uint64_t event)
{
    /* 虚拟中断由内核ISR收下，再统一转交给等待中的应用 */
    (void)dev_type;
    (void)event;
    return 0;
}
