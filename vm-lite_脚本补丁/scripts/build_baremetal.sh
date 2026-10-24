#!/usr/bin/env bash
#
# build_baremetal.sh —— 把 vm-lite guest 内核编成 QEMU 可引导的 ARM64 裸机镜像
#
# Termux 本机就是 aarch64，自带 clang 即可，无需任何交叉编译器。
#
# 产出: out/vm-lite.elf  (-kernel 直接加载)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/out"
mkdir -p "$OUT"

# ---------- 1. 编译器 ----------
if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    CC=aarch64-linux-gnu-gcc
    OBJCOPY=aarch64-linux-gnu-objcopy
    XFLAGS=""
    LDFLAGS_EXTRA=()
elif command -v clang >/dev/null 2>&1; then
    CC=clang
    command -v llvm-objcopy >/dev/null 2>&1 && OBJCOPY=llvm-objcopy || OBJCOPY=""
    # 裸机必须显式给 target，否则 clang 去找 Android/libc；
    # -fno-integrated-as 让 GNU as 处理汇编伪指令
    XFLAGS="-target aarch64-none-elf -fno-integrated-as"
    LDFLAGS_EXTRA=(-fuse-ld=lld)
else
    echo "[!] 找不到编译器。Termux 执行: pkg install clang binutils"
    exit 1
fi

echo "==== vm-lite 构建 (aarch64) ===="
echo "[*] 编译器 : $CC"
"$CC" --version 2>/dev/null | head -1 || true

# ---------- 2. 启动汇编（缺失则自动生成） ----------
START="$ROOT/platform/start64.S"
if [ ! -f "$START" ]; then
    echo "[*] 生成 platform/start64.S ..."
    mkdir -p "$ROOT/platform"
    cat > "$START" <<'EOF'
    .section .text.startup
    .global _start
_start:
    ldr     x30, =__stack_top
    mov     sp, x30
    ldr     x0, =__bss_start
    ldr     x1, =__bss_end
    mov     x2, #0
1:
    cmp     x0, x1
    b.ge    2f
    str     x2, [x0], #8
    b       1b
2:
    bl      kernel_main
3:
    wfi
    b       3b
EOF
fi

# ---------- 3. 编译 ----------
CFLAGS="-march=armv8-a -ffreestanding -nostdlib -fno-builtin \
-fno-stack-protector -O2 -Wall \
-I $ROOT/guest_kernel -I $ROOT/hwif -I $ROOT/platform"

echo "[*] 编译 guest_kernel + hwif + platform ..."

for pair in "guest_kernel/boot.c:boot.o" \
            "guest_kernel/broker.c:broker.o" \
            "guest_kernel/syscall.c:syscall.o" \
            "hwif/hwif.c:hwif.o" \
            "platform/uart.c:uart.o" \
            "platform/main.c:main.o"; do
    src="${pair%%:*}"; obj="${pair##*:}"
    printf "    %-26s " "$src"
    if $CC $XFLAGS $CFLAGS -c "$ROOT/$src" -o "$OUT/$obj" 2>"$OUT/.err"; then
        echo "OK"
    else
        echo "FAIL"; head -5 "$OUT/.err"; exit 1
    fi
done

printf "    %-26s " "platform/start64.S"
if $CC $XFLAGS $CFLAGS -c "$START" -o "$OUT/start64.o" 2>"$OUT/.err"; then
    echo "OK"
else
    echo "FAIL"; head -5 "$OUT/.err"; exit 1
fi

# ---------- 4. 链接 ----------
echo "[*] 链接 -> vm-lite.elf"
$CC $XFLAGS $CFLAGS "${LDFLAGS_EXTRA[@]}" -T "$ROOT/platform/link.ld" \
    "$OUT/start64.o" "$OUT/main.o" "$OUT/uart.o" \
    "$OUT/boot.o" "$OUT/broker.o" "$OUT/syscall.o" "$OUT/hwif.o" \
    -o "$OUT/vm-lite.elf" -nostartfiles -nostdlib -static 2>"$OUT/.err" || {
    echo "[!] 链接失败:"; cat "$OUT/.err"; exit 1
}

[ -n "$OBJCOPY" ] && command -v "$OBJCOPY" >/dev/null 2>&1 \
    && "$OBJCOPY" -O binary "$OUT/vm-lite.elf" "$OUT/vm-lite.bin"

echo "aarch64" > "$OUT/.arch"
rm -f "$OUT/.err"

echo
echo "[+] 构建完成:"
ls -lh "$OUT/vm-lite.elf" 2>/dev/null || echo "[!] elf 未生成"
echo
echo "    运行:  bash scripts/run_vm.sh"
