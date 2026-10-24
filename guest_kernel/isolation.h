#ifndef VM_LITE_GUEST_ISOLATION_H
#define VM_LITE_GUEST_ISOLATION_H

/*
 * Guest 内核 与 主内核（宿主内核）的隔离边界
 *
 * 三条互不穿透的规则：
 *
 *  1. syscall 不穿透
 *     Guest 用户态 svc -> Guest 内核 EL1。
 *     绝不会直接落到宿主内核。宿主内核看不到 Guest 的 syscall。
 *
 *  2. 地址空间不共享
 *     Guest 物理地址 (GPA) 经 Stage-2 页表翻译到宿主物理地址 (HPA)。
 *     Guest 内核持有的地址对宿主内核无意义。
 *
 *  3. 设备访问必经 VM exit
 *     Guest 内核访问虚拟设备寄存器 = MMIO 访问 -> Stage-2 fault
 *     -> trap 到 EL2 (VMM) -> VMM 决定模拟还是转发真实硬件。
 *     这是唯一允许跨越边界的通道。
 */

/* 边界穿越方向 */
typedef enum {
    EXIT_NONE     = 0,
    EXIT_MMIO     = 1,   /* Guest 访问设备寄存器 */
    EXIT_IRQ      = 2,   /* 真实硬件中断需要注入 Guest */
    EXIT_HYPERCALL= 3,   /* Guest 主动请求 VMM 服务 */
    EXIT_HVC      = 4    /* 虚拟化相关特权指令 */
} vm_exit_reason_t;

/* VM exit 交由 VMM 处理的唯一入口 */
int guest_exit_to_vmm(vm_exit_reason_t reason, uint64_t arg0, uint64_t arg1);

/* VMM 反向注入虚拟中断（真实硬件 -> 宿主内核 -> VMM -> Guest） */
int guest_inject_virtual_irq(unsigned int irq);

#endif /* VM_LITE_GUEST_ISOLATION_H */
