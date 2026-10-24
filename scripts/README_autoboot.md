# 开机自启 + 后台预热

## 思路

把 8 分钟冷启动藏到开机后台，用户感知为零：

```
开机 → 后台静默启动(8~12分钟) → 自动存快照 → 通知「就绪」
之后每次打开 → 秒级加载快照
```

**8 分钟只付一次，且在后台、无人感知。**

## 三种安装方式

| 方式 | 适用设备 | 说明 |
|---|---|---|
| **A. Termux:Boot** | Android 7+ | 最简单。必须与 Termux 同一签名来源 |
| **B. init 服务（root）** | R17 | 最稳，init 被杀后会自动重启（默认5秒） |
| **C. 手动** | 任意 | `bash autoboot.sh &` |

### A 的关键三步（漏一步就不生效）
1. 装 Termux:Boot（**与 Termux 同来源签名**，混装会报签名不匹配）
2. **打开一次 Termux:Boot 图标** ← 这步不做，永远不会触发
3. `mkdir -p ~/.termux/boot` 并把脚本放进去，加执行权限

### B 的写法（root）
```
# /etc/init/custom.rc
service vm /system/bin/sh /data/local/tmp/vm/autoboot.sh
    disabled
    seclabel u:r:magisk:s0
on property:sys.boot_completed=1
    start vm
```
init 会在服务被杀后约 5 秒自动重启。

## 必须注意

1. **先 `termux-wake-lock` 再干任何事** —— 不取锁，息屏后 CPU 休眠直接卡死
2. **电池优化白名单** —— Termux 和 Termux:Boot 都要设「不优化」
3. **等 30 秒再启动** —— 开机瞬间 CPU/IO 极忙，抢着跑反而更慢
4. **后台比前台更慢** —— MT6750 满载撑 200 秒就降频，后台还额外限频，可能 10~12 分钟。但用户不用等，仍然划算

## ⚠️ A59S (Android 5.1) 的硬伤

Termux 对 Android 5/6 的支持 **2020-01-01 v0.83 起已停止**：
- 必须用 `apt-android-5` 变体
- 包仓库 termux.net **已无法连接**
- **qemu 这类包大概率装不上**

这是地基问题，比 8 分钟严重。建议改用 R17（Android 8.1/10 + root），
Termux 完整支持，且 root 后可走方式 B 的 init 服务，最稳。
