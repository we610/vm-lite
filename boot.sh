#!/system/bin/sh
# ============================================================
# 安卓虚拟机启动脚本 v1.6
# 架构: ARM32 / ARMv7-A guest (qemu-system-arm, 非 aarch64)
# 模式: 纯 TCG 软虚拟化 (无 KVM)
# 宿主: Android 5.0+ / 32位 ARM (A59 / A59S)
# 全部组件均为预编译二进制, 运行时零编译
# ============================================================

BASE_DIR=/data/local/tmp/vm
KERNEL=$BASE_DIR/zImage-cortex-a15-3.10.108
DTB=$BASE_DIR/virt.dtb
ROOTFS=$BASE_DIR/rootfs.ext4
QEMU=$BASE_DIR/qemu-system-arm
MODULE_DIR=$BASE_DIR/modules

# ---------- 可调参数 ----------
# guest 内存: A59 建议 512, A59S 建议 768
VM_MEM=${VM_MEM:-768}
# vCPU 数: 甜点值为 4 (Android 启动最多利用 4~5 核, 超过无收益)
# 实测建议: 先试 1 / 2 / 4 三档择优
VM_SMP=${VM_SMP:-4}
# TB 缓存: 保持默认 32MB。调大对启动收益有限(5~10%)但费内存, 不建议
TB_SIZE=${TB_SIZE:-32}

# ---------- 01. 检查 Android 版本 (API 21 = Android 5.0) ----------
SDK=$(getprop ro.build.version.sdk)
if [ -z "$SDK" ] || [ "$SDK" -lt 21 ]; then
    echo "[ERR] 需要 Android 5.0 (API 21)+, 当前 SDK=$SDK"
    exit 1
fi
echo "[OK] Android SDK: $SDK"

# ---------- 02. 检查 CPU 架构 ----------
CPU_INFO=$(grep -m1 "Processor" /proc/cpuinfo 2>/dev/null || grep -m1 "model name" /proc/cpuinfo 2>/dev/null)
echo "[OK] CPU: $CPU_INFO"

# ---------- 03. 校验二进制产物是否齐全 ----------
for f in "$QEMU" "$KERNEL" "$DTB" "$ROOTFS"; do
    if [ ! -f "$f" ]; then
        echo "[ERR] 缺少二进制文件: $f"
        exit 1
    fi
done
echo "[OK] 二进制产物校验通过"

# ---------- 04. 加载内核模块 (可选, 由内核管理器提供 .ko) ----------
# if [ -d "$MODULE_DIR" ]; then
#     for ko in $MODULE_DIR/*.ko; do
#         insmod "$ko"
#     done
# fi

# ---------- 05. 启动虚拟机 (ARM32 纯 TCG) ----------
# 架构说明:
#   qemu-system-arm  = 32位 ARM guest (ARMv7-A), 本项目采用
#   qemu-system-aarch64 = 64位 ARM guest, 本项目不使用
#   -cpu cortex-a15  = virt 机型默认 CPU, 属简单模型,
#                      可规避 -cpu max 的原子指令锁竞争问题
#   -machine virt    = 支持多核; 注意 GICv2 上限 8 核, smp4 安全
#   因 guest 为 ARM32, 无指针认证(pauth)开销(该特性仅 ARMv8.3+)
# 图形输出走 VNC, 宿主机用 VNC 客户端连接查看安卓桌面
# 调试模式: 把下面 -vnc 一行换成 -nographic 可切到纯串口控制台
echo "[..] 启动虚拟机 (ARM32 TCG, mem=${VM_MEM}M smp=${VM_SMP})..."

exec "$QEMU" \
    -machine virt \
    -cpu cortex-a15 \
    -accel tcg \
    -smp "$VM_SMP" \
    -m "$VM_MEM" \
    -kernel "$KERNEL" \
    -dtb "$DTB" \
    -append "console=ttyAMA0 root=/dev/vda rw androidboot.hardware=generic" \
    -drive file="$ROOTFS",if=virtio,format=raw \
    -netdev user,id=net0 \
    -device virtio-net-device,netdev=net0 \
    -device virtio-gpu-pci \
    -vnc :0 \
    -no-reboot
