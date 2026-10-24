#!/usr/bin/env bash
#
# install_qemu_termux.sh —— vm-lite 环境安装（aarch64 优先版）
#
# 关键改动：不再强求 ARM32 交叉编译器（ndk-multilib 在 Termux 上常装不上）。
# Termux 本机就是 aarch64，自带 clang 即可编译，无需交叉。
# 想回头做 ARM32 时再加 --arm32。
#
# 用法:
#   bash scripts/install_qemu_termux.sh             # 装 aarch64 环境（够用）
#   bash scripts/install_qemu_termux.sh --arm32     # 额外装 ARM32 交叉编译器
#
set -euo pipefail

ARM32=0
[ "${1:-}" = "--arm32" ] && ARM32=1

echo "==== vm-lite / Termux 环境安装 (aarch64) ===="

# ---------- 0. 授权存储 ----------
echo "[0/5] 授权存储 ..."
if [ -d "$HOME/storage" ]; then
    echo "    [i] ~/storage 已存在，跳过（不会删除任何文件）"
else
    termux-setup-storage 2>/dev/null || true
    sleep 2
fi

# ---------- 1. 更新 ----------
echo "[1/5] 更新包索引 ..."
pkg update -y

# ---------- 2. QEMU ----------
echo "[2/5] 安装 QEMU ..."
if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
    pkg install -y qemu-system-aarch64 qemu-utils
else
    echo "    [i] qemu-system-aarch64 已存在，跳过"
fi

# ---------- 3. 编译器（aarch64 路线） ----------
echo "[3/5] 安装 clang + binutils + git ..."
pkg install -y clang binutils git

# ---------- 4. 可选 ARM32 ----------
echo "[4/5] ARM32 交叉编译器 ..."
if [ "$ARM32" = "1" ]; then
    pkg install -y ndk-multilib 2>/dev/null \
        && echo "    [+] ARM32 已装" \
        || echo "    [!] ndk-multilib 装不上，继续用 aarch64（不影响）"
else
    echo "    [i] 跳过（aarch64 路线不需要；加 --arm32 可装）"
fi

# ---------- 5. 验证 ----------
echo "[5/5] 验证 ..."
echo "-------------------------------------------------"
OK=1

if command -v qemu-system-aarch64 >/dev/null 2>&1; then
    echo "[✓] QEMU   : $(qemu-system-aarch64 --version | head -1)"
else
    echo "[✗] QEMU 缺失"; OK=0
fi

if command -v clang >/dev/null 2>&1; then
    echo "[✓] clang  : $(clang --version | head -1)"
else
    echo "[✗] clang 缺失"; OK=0
fi

command -v git >/dev/null 2>&1 \
    && echo "[✓] git    : $(git --version)" \
    || echo "[~] git 缺失"

echo "-------------------------------------------------"

if [ "$OK" = "1" ]; then
    echo "[+] 环境就绪 (aarch64)"
    echo
    echo "下一步:"
    echo "  cd ~/vm-lite"
    echo "  bash scripts/build_baremetal.sh"
    echo "  bash scripts/run_vm.sh"
else
    echo "[!] 环境不完整，检查上面的报错"
    exit 1
fi
