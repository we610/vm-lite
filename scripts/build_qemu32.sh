#!/usr/bin/env bash
#
# build_qemu32.sh —— 编译真正的 32 位 QEMU (qemu-system-arm / arm-softmmu)
#
# 为什么需要这个:
#   Termux 官方仓库只有 qemu-system-aarch64，没有 qemu-system-arm。
#   aarch64 版虽然能靠 -cpu cortex-a15 降级跑 32 位裸机，
#   但要真正验证 ARM32 行为（尤其是后面要加的 Stage-2 / EL2 部分），
#   必须有原生的 arm-softmmu。
#
# 用法:
#   bash scripts/build_qemu32.sh              # 装到 $PREFIX (Termux) 或 $HOME/qemu32
#   bash scripts/build_qemu32.sh --prefix DIR # 指定安装目录
#
set -euo pipefail

QEMU_VER="${QEMU_VER:-8.2.0}"
JOBS="$(nproc 2>/dev/null || echo 4)"
SRC_DIR="${SRC_DIR:-$HOME/qemu-src}"

if [ "${1:-}" = "--prefix" ] && [ -n "${2:-}" ]; then
    PREFIX="$2"
elif [ -n "${PREFIX:-}" ]; then
    PREFIX="$PREFIX"
else
    PREFIX="$HOME/qemu32"
fi

echo "==== 编译 32 位 QEMU (arm-softmmu) ===="
echo "  版本   : $QEMU_VER"
echo "  源码   : $SRC_DIR"
echo "  安装到 : $PREFIX"
echo "  并行   : $JOBS"
echo

# ---------- 0. 依赖 ----------
echo "[0/4] 安装依赖 ..."
if command -v pkg >/dev/null 2>&1; then
    # Termux
    pkg install -y -qq git python ninja pkg-config \
        libglib ninja meson 2>/dev/null || true
    pkg install -y -qq glib binutils libandroid-support 2>/dev/null || true
elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq git python3 python3-pip ninja-build \
        pkg-config libglib2.0-dev libpixman-1-dev flex bison \
        build-essential zlib1g-dev
fi

# ---------- 1. 取源码 ----------
echo "[1/4] 获取 QEMU 源码 ..."
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

if [ ! -d "qemu-$QEMU_VER" ]; then
    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 --branch "v$QEMU_VER" \
            https://github.com/qemu/qemu.git "qemu-$QEMU_VER" 2>/dev/null \
        || git clone --depth 1 https://github.com/qemu/qemu.git "qemu-$QEMU_VER"
    fi
fi

if [ ! -d "qemu-$QEMU_VER" ]; then
    echo "[!] 无法获取源码，请手动下载 qemu-$QEMU_VER.tar.xz 到 $SRC_DIR"
    exit 1
fi

cd "qemu-$QEMU_VER"

# ---------- 2. 配置：只要 32 位 ARM ----------
echo "[2/4] configure (只编 arm-softmmu) ..."

rm -rf build32 && mkdir -p build32 && cd build32

../configure \
    --target-list=arm-softmmu \
    --prefix="$PREFIX" \
    --disable-kvm \
    --disable-xen \
    --disable-gtk \
    --disable-sdl \
    --disable-vnc \
    --disable-opengl \
    --disable-alsa \
    --disable-pa \
    --disable-docs \
    --disable-tools \
    --disable-user \
    --disable-bsd-user \
    --enable-virtfs 2>&1 | tail -20

# ---------- 3. 编译 ----------
echo "[3/4] make -j$JOBS ..."
make -j"$JOBS" 2>&1 | tail -25

# ---------- 4. 安装 ----------
echo "[4/4] make install ..."
make install 2>&1 | tail -10

echo
echo "========================================="
if [ -x "$PREFIX/bin/qemu-system-arm" ]; then
    echo "[+] 32 位 QEMU 就绪:"
    "$PREFIX/bin/qemu-system-arm" --version | head -1
    echo
    echo "    把它加进 PATH:"
    echo "      export PATH=$PREFIX/bin:\$PATH"
    echo "    或建软链:"
    echo "      ln -sf $PREFIX/bin/qemu-system-arm \$PREFIX/bin/"
else
    echo "[!] 未找到产物，检查上面的编译日志"
    exit 1
fi
