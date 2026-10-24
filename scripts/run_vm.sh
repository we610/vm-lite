#!/usr/bin/env bash
#
# run_vm.sh —— 用 QEMU (aarch64) 启动 vm-lite guest 内核
#
# 用法:
#   bash scripts/run_vm.sh                  # 直接跑，串口输出
#   bash scripts/run_vm.sh --timeout 10     # 跑 10 秒自动退出（推荐）
#   bash scripts/run_vm.sh --gdb            # -S -s，等 gdb 连入 1234
#   bash scripts/run_vm.sh --virt           # 开 EL2 虚拟化
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ELF="$ROOT/out/vm-lite.elf"

[ -f "$ELF" ] || {
    echo "[!] 没有 $ELF"
    echo "    先跑:  bash scripts/build_baremetal.sh"
    exit 1
}

command -v qemu-system-aarch64 >/dev/null 2>&1 || {
    echo "[!] 缺 qemu-system-aarch64"
    echo "    Termux: pkg install qemu-system-aarch64"
    exit 1
}

GDB=0; VIRT=0; TIMEOUT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --gdb)     GDB=1; shift ;;
        --virt)    VIRT=1; shift ;;
        --timeout) TIMEOUT="${2:-15}"; shift 2 ;;
        *)         shift ;;
    esac
done

MACHINE=virt
[ "$VIRT" = "1" ] && MACHINE="virt,virtualization=on"

echo "[*] 架构   : aarch64"
echo "[*] CPU    : cortex-a57 (ARMv8-A)"
echo "[*] 镜像   : $ELF"
echo "[*] 机型   : $MACHINE"
echo "[*] 串口   : PL011 @ 0x09000000 (-nographic)"
[ -n "$TIMEOUT" ] && echo "[*] 超时   : ${TIMEOUT}s 后自动退出"
echo "-------------------------------------------------"

CMD=(qemu-system-aarch64 -M "$MACHINE" -cpu cortex-a57 \
     -kernel "$ELF" -nographic -m 256M -smp 1)

[ "$GDB" = "1" ] && { echo "[i] 等待 gdb 连接 :1234"; CMD+=(-S -s); }

if [ -n "$TIMEOUT" ]; then
    timeout "$TIMEOUT" "${CMD[@]}" || {
        echo "-------------------------------------------------"
        echo "[i] ${TIMEOUT}s 到，已自动结束"
    }
else
    echo "[i] 退出: Ctrl-A 松开后按 X（或另开会话 pkill qemu-system-aarch64）"
    exec "${CMD[@]}"
fi
