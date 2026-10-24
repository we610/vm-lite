# Guest 内核：与主内核分离

## 分层（修正版）

```
Guest 用户态 (app)
      │  svc 指令 = syscall
      ▼
Guest 内核 EL1   ←── 独立 syscall 表、独立地址空间、独立进程管理
      │
      │  MMIO 访问设备寄存器 → Stage-2 fault
      ▼
VMM (EL2)        ←── 唯一允许跨越的边界
      │
      ▼
宿主内核（主内核）→ 真实硬件
```

## 两条链的区别

**下行（Guest 要硬件做事）**
```
app → syscall → Guest 内核 → 驱动写 MMIO
     → Stage-2 fault → VM exit → VMM → 宿主内核 → 真实硬件
```

**上行（硬件有事通知）**
```
真实硬件 → IRQ → 宿主内核 → VMM
     → 注入虚拟中断 (GIC List Register) → Guest 内核 → 驱动 → 唤醒 app
```

## 三条铁律

1. **syscall 不穿透** —— Guest 的 svc 陷进的是自己的 EL1，宿主内核看不见
2. **地址空间不共享** —— GPA 经 Stage-2 翻译到 HPA，Guest 地址对宿主无意义
3. **设备访问必经 VM exit** —— MMIO trap 是唯一合法跨界通道，硬件自动完成

## 易错点

「硬件走 syscall 和内核通信」这个说法需要修正：
- syscall 是**软件发起**的同步调用（svc，EL0→EL1）
- 硬件通知内核是**异步中断**（IRQ），不是 syscall
- 虚拟硬件（virtio）通知 Guest 靠 VMM **注入虚拟中断**
- Guest 内核访问虚拟设备靠 **MMIO**，会触发 VM exit

所以准确说法是：
**应用软件走 syscall 进 Guest 内核；硬件走中断（虚拟中断）通知 Guest 内核。**

---

# 内核作中枢（补充）

## 三方结构

```
虚拟硬件  <——>  内核(Broker)  <——>  应用
```

- 应用不直接碰虚拟硬件 → 发 syscall，内核代劳
- 虚拟硬件不直接通知应用 → 虚拟中断先给内核，内核转交
- 应用只拿到 fd/token，**真实设备句柄永远留在内核**

## 调用汇聚

```
应用 syscall → guest_syscall_dispatch → broker_handle → hwif → 设备
虚拟硬件事件 → 虚拟中断 → 内核ISR → broker_deliver_event → 唤醒应用
```

## 启动由内核主导

七阶段严格串行（不可跳），阶段内按 class 并行：

| 阶段 | 内容 | 超时 |
|---|---|---|
| KERNEL | 内核自检、驱动初始化 | 5s |
| ROOTFS | 挂载根文件系统 | 10s |
| INIT | 拉起 init | 5s |
| DAEMON | 守护进程（并行） | 20s |
| SERVER | system_server 核心服务 | 60s |
| UI | 极简桌面 + SystemUI | 15s |
| READY | 广播就绪 | 1s |

阶段不可跳：`guest_boot_advance` 会拒绝 `stage != current+1`。
每阶段独立超时 → 卡住能定位到具体阶段，不用干等。

> SERVER 阶段 60s 是最长项，与 7.4「system_server 是冷启动最大瓶颈」一致。
