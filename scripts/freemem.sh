#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# Termux 运存清理脚本 —— 为 QEMU 虚拟机腾出内存
# 用法: bash freemem.sh [light|normal|deep]
#   light  : 仅清 Termux 自身，最安全
#   normal : + 杀用户后台应用（无需 root）
#   deep   : + 禁用预装/OEM 应用、清页缓存（需要 root）
# ============================================================

MODE=${1:-normal}

mem_of() {
    # 读取 MemAvailable（单位转 MB）
    awk '/MemAvailable|MemTotal/ {printf "%d ", $2/1024}' /proc/meminfo
}

echo "=== 清理前 ==="
read -r TOTAL AVAIL <<<"$(mem_of)"
echo "总内存: ${TOTAL} MB   可用: ${AVAIL} MB"

# ---------- 所有模式都做：清 Termux 自身 ----------
echo
echo "[1] 清理 Termux 自身"
pkg clean 2>/dev/null                 # 清 apt 包缓存
rm -rf ~/.cache/* 2>/dev/null         # 清用户缓存
rm -f /data/data/com.termux/files/usr/tmp/* 2>/dev/null

# 杀掉 Termux 内多余会话/进程（保留当前 shell 与其父进程）
for p in $(pgrep -f "com.termux" 2>/dev/null); do
    [ "$p" = "$$" ] && continue
    [ "$p" = "$PPID" ] && continue
    kill -9 "$p" 2>/dev/null
done

if [ "$MODE" = "light" ]; then
    read -r _ AVAIL2 <<<"$(mem_of)"
    echo
    echo "=== 清理后 ==="
    echo "可用: ${AVAIL2} MB  (本轮释放 $((AVAIL2-AVAIL)) MB)"
    exit 0
fi

# ---------- normal：杀用户后台应用 ----------
echo
echo "[2] 杀掉后台应用（无需 root）"
# am kill-all 只杀"可杀"的后台进程，不影响前台与系统核心
am kill-all 2>/dev/null

# 再对已知吃内存的大户做定向回收（失败静默，普通权限下会被拒）
for pkg_name in \
    com.android.browser \
    com.oppo.music \
    com.oppo.video \
    com.heytap.market \
    com.nearme.gamecenter \
    com.coloros.gallery \
    com.android.gallery3d \
    com.tencent.mobileqq \
    com.tencent.mm ; do
    am force-stop "$pkg_name" 2>/dev/null
done

if [ "$MODE" = "normal" ]; then
    read -r _ AVAIL2 <<<"$(mem_of)"
    echo
    echo "=== 清理后 ==="
    echo "可用: ${AVAIL2} MB  (本轮释放 $((AVAIL2-AVAIL)) MB)"
    echo
    echo "提示: 若要深度清理，请以 root 执行: bash $0 deep"
    exit 0
fi

# ---------- deep：需要 root ----------
if [ "$(id -u)" != "0" ]; then
    echo
    echo "[!] deep 模式需要 root，当前不是 root，已跳过"
    exit 1
fi

echo
echo "[3] 深度清理（root）"

# 3a. 禁用 OEM 预装与不用的应用
#     注意: 用 disable-user 而非卸载，出问题可恢复
echo "  禁用预装应用（disable-user，可恢复）..."
for pkg_name in \
    com.heytap.market \
    com.nearme.gamecenter \
    com.oppo.music \
    com.oppo.video \
    com.coloros.gallery \
    com.coloros.video \
    com.coloros.weather \
    com.coloros.weather2 \
    com.coloros.assistantscreen \
    com.coloros.speechassist \
    com.oppo.reader \
    com.coloros.karaoke \
    com.nearme.statistics.rom \
    com.coloros.sau ; do
    pm disable-user --user 0 "$pkg_name" 2>/dev/null
done

# 3b. 清页缓存（多数 Android 内核受限，失败属正常）
echo "  尝试释放页缓存..."
if [ -w /proc/sys/vm/drop_caches ]; then
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null \
        && echo "    drop_caches 成功" \
        || echo "    drop_caches 被内核拒绝（常见，无妨）"
else
    echo "    /proc/sys/vm/drop_caches 不可写，跳过"
fi

# 3c. 提高前台进程重要性，避免 QEMU 自己被杀
echo "  提升 QEMU 优先级准备..."
QPID=$(pgrep -f qemu-system 2>/dev/null | head -1)
if [ -n "$QPID" ]; then
    renice -n -20 "$QPID" 2>/dev/null && echo "    QEMU(pid $QPID) 已 renice -20"
fi

read -r _ AVAIL2 <<<"$(mem_of)"
echo
echo "=== 清理后 ==="
echo "可用: ${AVAIL2} MB  (累计释放 $((AVAIL2-AVAIL)) MB)"
echo
echo "=== 后续建议 ==="
echo "  1. 先取锁防休眠: termux-wake-lock"
echo "  2. 在 tmux 里跑 boot.sh，避免窗口关闭导致进程终止"
echo "  3. 首次冷启动请插电并注意散热"
