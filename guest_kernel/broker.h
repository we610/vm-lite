#ifndef VM_LITE_GUEST_BROKER_H
#define VM_LITE_GUEST_BROKER_H

/*
 * 内核代理层（Broker）
 *
 * 定位：Guest 内核是唯一中枢。
 *   虚拟硬件  <-> 内核  <-> 应用
 *
 * 规则：
 *   1. 应用不直接碰虚拟硬件，一律发 syscall 请求内核代劳
 *   2. 虚拟硬件不直接通知应用，一律先把虚拟中断交给内核
 *   3. 内核统一持有 hwif 设备句柄，做权限校验与资源记账
 */

#include "syscall.h"

/* 代理请求类型 */
typedef enum {
    BROKER_REQ_OPEN  = 0,
    BROKER_REQ_READ  = 1,
    BROKER_REQ_WRITE = 2,
    BROKER_REQ_IOCTL = 3,
    BROKER_REQ_MMAP  = 4
} broker_req_type_t;

/* 代理请求：由 syscall 参数封装而来 */
typedef struct {
    broker_req_type_t type;
    uint64_t          dev_type;   /* hwif_dev_type_t */
    uint64_t          arg0;
    uint64_t          arg1;
    uint64_t          arg2;
} broker_req_t;

/* 内核代理入口：所有设备调用的唯一汇聚点 */
int broker_handle(const broker_req_t *req, uint64_t *out_ret);

/* 虚拟中断到达时，由内核统一转交应用 */
int broker_deliver_event(uint64_t dev_type, uint64_t event);

#endif /* VM_LITE_GUEST_BROKER_H */
