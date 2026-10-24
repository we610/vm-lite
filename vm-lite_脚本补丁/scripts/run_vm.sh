#!/usr/bin/env bash
#
# run_vm.sh —— 用 QEMU (aarch64) 启动 vm-lite guest 内核
#
# 用法:
#   bash scripts/run_vm.sh              # 直接跑，串口输出
#   bash scripts/run_vm.sh --gdb        # -S -s，等 gdb 连入 1234
#   bash scripts/run_vm.sh --virt       # 开 EL2 虚拟化（后面做 VMM 用）
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

GDB=0; VIRT=0
for arg in "$@"; do
    case "$arg" in
        --gdb)  GDB=1 ;;
        --virt) VIRT=1 ;;
    esac
done

MACHINE=virt
[ "$VIRT" = "1" ] && MACHINE="virt,virtualization=on"

echo "[*] 架构   : aarch64"
echo "[*] QEMU   : qemu-system-aarch64"
echo "[*] CPU    : cortex-a57  (ARMv8-A)"
echo "[*] 镜像   : $ELF"
echo "[*] 机型   : $MACHINE  ${VIRT:+(EL2 已开)}"
echo "[*] 内存   : 256M / 1核"
echo "[*] 串口   : PL011 @ 0x09000000 (-nographic)"
echo "-------------------------------------------------"
echo "[i] 退出: Ctrl-A 松开后按 X"
echo "-------------------------------------------------"

CMD=(qemu-system-aarch64 -M "$MACHINE" -cpu cortex-a57 \
     -kernel "$ELF" -nographic -m 256M -smp 1)

if [ "$GDB" = "1" ]; then
    echo "[i] 已停在启动处，等待 gdb 连接 :1234"
    CMD+=(-S -s)
fi

exec "${CMD[@]}"
