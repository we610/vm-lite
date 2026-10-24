#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# 优学派 U36 专用运存清理脚本
#
# U36 特点:
#   MT6797X (Helio X27) 十核, 20nm, 发热降频严重
#   3GB RAM —— 硬伤, 与 A59 同档, 必须清理才够用
#   优学派定制系统 + 家长管控, 预装包名与 ColorOS 完全不同
#
# 用法: bash freemem_u36.sh [light|normal|deep]
# ============================================================

MODE=${1:-normal}

mem_mb() { awk '/MemAvailable/{printf "%d", $2/1024}' /proc/meminfo; }
AVAIL=$(mem_mb)
TOTAL=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)

echo "=== U36 清理前 ==="
echo "总内存: ${TOTAL} MB   可用: ${AVAIL} MB"

# ---------- 所有模式：清 Termux 自身 ----------
echo
echo "[1] 清理 Termux 自身"
pkg clean 2>/dev/null
rm -rf ~/.cache/* 2>/dev/null
for p in $(pgrep -f "com.termux" 2>/dev/null); do
    [ "$p" = "$$" ] && continue
    [ "$p" = "$PPID" ] && continue
    kill -9 "$p" 2>/dev/null
done

if [ "$MODE" = "light" ]; then
    echo; echo "可用: $(mem_mb) MB (释放 $(( $(mem_mb) - AVAIL )) MB)"; exit 0
fi

# ---------- normal：杀后台（无需 root）----------
echo
echo "[2] 回收后台应用"
am kill-all 2>/dev/null

# 优学派学习机常见吃内存大户（包名与 ColorOS 不同，勿混用）
for p in \
    com.android.browser \
    com.youxuepai.market \
    com.youxuepai.appstore \
    com.youxuepai.video \
    com.youxuepai.music \
    com.youxuepai.reader \
    com.youxuepai.ai \
    com.youxuepai.parent \
    com.youxuepai.ar \
    com.android.gallery3d \
    com.android.music \
    com.android.video \
    com.tencent.mobileqq \
    com.tencent.mm ; do
    am force-stop "$p" 2>/dev/null
done

if [ "$MODE" = "normal" ]; then
    echo; echo "可用: $(mem_mb) MB (释放 $(( $(mem_mb) - AVAIL )) MB)"
    echo "提示: 深度清理请 root 后执行 bash $0 deep"
    exit 0
fi

# ---------- deep：需要 root ----------
if [ "$(id -u)" != "0" ]; then
    echo; echo "[!] deep 需要 root，当前非 root，跳过"
    exit 1
fi

echo
echo "[3] 深度清理 (root)"

echo "  禁用预装（disable-user，可恢复）..."
for p in \
    com.youxuepai.market \
    com.youxuepai.appstore \
    com.youxuepai.video \
    com.youxuepai.music \
    com.youxuepai.reader \
    com.youxuepai.parent \
    com.youxuepai.ar \
    com.android.gallery3d \
    com.android.music \
    com.android.video \
    com.mediatek.* ; do
    pm disable-user --user 0 "$p" 2>/dev/null
done

echo "  尝试释放页缓存..."
if [ -w /proc/sys/vm/drop_caches ]; then
    sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null \
        && echo "    成功" || echo "    被内核拒绝（常见，无妨）"
else
    echo "    不可写，跳过"
fi

# U36 只有 2 个 A72 大核，把 QEMU 的 vCPU 线程绑上去
echo "  尝试将 QEMU 绑到大核..."
QPIDS=$(pgrep -f qemu-system 2>/dev/null)
if [ -n "$QPIDS" ]; then
    for pid in $QPIDS; do
        renice -n -20 "$pid" 2>/dev/null
        # 十核三丛集: CPU0-1=A72大核(2.5G), 2-5=A53(2.0G), 6-9=A53(1.4G)
        taskset -p -c 0-5 "$pid" 2>/dev/null >/dev/null
    done
    echo "    QEMU 已 renice -20"
fi

echo
echo "=== 清理后 ==="
echo "可用: $(mem_mb) MB (累计释放 $(( $(mem_mb) - AVAIL )) MB)"
echo
echo "=== U36 特别提示 ==="
echo "  1. 3GB 运存是硬伤，建议 -m 512（不要超过 640）"
echo "  2. 20nm 发热严重，满载会从 2.5GHz 掉到 1.4GHz"
echo "  3. 务必插电 + 取下保护壳，平板散热比手机略好但仍会降频"
echo "  4. 先 termux-wake-lock，再用 tmux 跑 boot.sh"
