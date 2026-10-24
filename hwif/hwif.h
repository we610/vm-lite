#ifndef VM_LITE_HWIF_H
#define VM_LITE_HWIF_H

/*
 * hwif.h —— 硬件统一 C 接口契约
 *
 * 设计原则：
 *   真实硬件与虚拟硬件实现同一套 hwif_ops，
 *   Guest 内核只认 hwif_ops，不认背后是物理设备还是 VMM 模拟设备。
 *   因此 Guest 系统无需区分「真机 / 虚拟机」，行为完全一致。
 */

#include <stdint.h>
#include <stddef.h>

/* 设备类型：真实硬件与虚拟硬件共用同一套编号 */
typedef enum {
    HWIF_DEV_STORAGE = 0,   /* 块设备：eMMC/UFS  <->  virtio-blk  */
    HWIF_DEV_NET     = 1,   /* 网卡：  WLAN      <->  virtio-net  */
    HWIF_DEV_CONSOLE = 2,   /* 串口：  UART      <->  virtio-console */
    HWIF_DEV_GPU     = 3,   /* 显示：  framebuffer <-> virtio-gpu */
    HWIF_DEV_INPUT   = 4,   /* 输入：  触摸屏     <->  virtio-input */
    HWIF_DEV_MAX
} hwif_dev_type_t;

/* 后端标识：仅用于调试与统计，Guest 内核不得据此分支 */
typedef enum {
    HWIF_BACKEND_PHYSICAL = 0,  /* 真实硬件驱动（宿主机 .ko） */
    HWIF_BACKEND_VIRTUAL  = 1   /* VMM 虚拟设备（virtio 等）  */
} hwif_backend_t;

/* 统一操作集 —— 真实硬件与虚拟硬件都必须完整实现 */
typedef struct hwif_ops {
    int  (*open)   (void *ctx);
    int  (*close)  (void *ctx);
    int  (*read)   (void *ctx, void *buf, size_t len);
    int  (*write)  (void *ctx, const void *buf, size_t len);
    int  (*ioctl)  (void *ctx, unsigned int cmd, unsigned long arg);
    void *(*mmap)  (void *ctx, size_t len, int prot);
    int  (*irq_ack)(void *ctx, unsigned int irq);
} hwif_ops_t;

/* 设备描述符 */
typedef struct hwif_device {
    hwif_dev_type_t  type;
    hwif_backend_t   backend;   /* 透明：Guest 不读此字段做逻辑分支 */
    const char      *name;
    void            *priv;
    const hwif_ops_t *ops;
} hwif_device_t;

/* 注册 / 注销 —— 真实驱动与虚拟设备走同一入口 */
int  hwif_register  (hwif_device_t *dev);
int  hwif_unregister(hwif_device_t *dev);

/* 查找 —— Guest 内核只按 type 取设备，不关心后端 */
hwif_device_t *hwif_get(hwif_dev_type_t type);

#endif /* VM_LITE_HWIF_H */
