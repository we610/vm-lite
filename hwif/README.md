# hwif —— 硬件统一 C 接口层

## 分层

```
真实硬件 (eMMC / WLAN / UART / GPU / 触摸屏)
        |  C 接口 (hwif_ops)
        v
宿主内核 —————————————————————————
        |  VMM (QEMU / kvmtool)
        |  虚拟硬件: virtio-blk / virtio-net / virtio-console / virtio-gpu / virtio-input
        |  C 接口 (hwif_ops，同一套契约)
        v
Guest 内核 (只认 hwif_ops，不认后端)
        |
        v
Guest 系统 (Android)
```

## 透明性原则

`hwif_device_t.backend` 字段仅用于调试与统计。
Guest 内核**不得**读取该字段做逻辑分支——一旦分支，
Guest 就能感知自己在虚拟机里，透明性即被破坏。

正确做法：`hwif_get(HWIF_DEV_STORAGE)` 拿到设备直接用，
不关心它背后是 eMMC 还是 virtio-blk。

## 文件

- `hwif.h` —— 接口契约（真实硬件与虚拟硬件共用）
- `hwif.c` —— 注册表实现（两种后端待遇完全相同）
