#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# 开机自启 + 后台预热 —— 把 8 分钟冷启动藏到后台
#
# 安装方式(三选一, 按设备):
#   [A] Termux:Boot (Android 7+, 最简单)
#       1. 装 Termux:Boot (必须与 Termux 同一来源签名)
#       2. 【打开一次】Termux:Boot 图标 —— 这步不做就不会生效
#       3. mkdir -p ~/.termux/boot
#       4. cp autoboot.sh ~/.termux/boot/ && chmod +x
#
#   [B] root 设备用 init 服务 (R17, 最稳)
#       写 /data/adb/service.d/vm.sh 或 /etc/init/custom.rc
#       init 会在服务被杀后自动重启(默认5秒)
#
#   [C] 手动: 直接 bash autoboot.sh &
#
# 关键: 脚本启动后自己进后台, 不阻塞开机
# ============================================================

BASE_DIR=${BASE_DIR:-/data/local/tmp/vm}
LOG=$BASE_DIR/autoboot.log
SNAP=$BASE_DIR/snapshot_ready.flag

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

log "=== autoboot 启动 ==="

# ---------- 01. 取唤醒锁(必须第一件事) ----------
# 不取锁, 息屏后 CPU 休眠, 启动直接卡死
termux-wake-lock 2>/dev/null && log "wake-lock 已获取" \
                             || log "[warn] wake-lock 失败(非Termux环境?)"

# ---------- 02. 等待系统就绪 ----------
# 开机瞬间 CPU/IO 极忙, 立刻启动只会更慢
sleep 30
log "等待开机风暴结束"

# ---------- 03. 有快照就直接加载, 跳过冷启动 ----------
if [ -f "$SNAP" ] || [ -f "$BASE_DIR/vm.state" ]; then
    log "检测到快照 -> 走快速恢复路径(秒级)"
    "$BASE_DIR/load_snapshot.sh" 2>>"$LOG"
    termux-notification --title "虚拟机就绪" --content "快照恢复完成" 2>/dev/null
    log "快速恢复完成"
    exit 0
fi

# ---------- 04. 无快照 -> 后台冷启动 ----------
log "无快照 -> 后台冷启动(预计 8~12 分钟)"

# nice -20 提优先级, 降低被杀概率
nice -n -20 "$BASE_DIR/boot.sh" >>"$LOG" 2>&1 &
VPID=$!
log "boot.sh 已在后台启动 (pid=$VPID)"

# ---------- 05. 守护: 监视是否完成 ----------
# 轮询等待桌面就绪, 完成后自动存快照并通知
(
    TIMEOUT=1200   # 20 分钟上限
    N=0
    while [ $N -lt $TIMEOUT ]; do
        if ! kill -0 "$VPID" 2>/dev/null; then
            log "[err] QEMU 进程已退出(可能被杀)"
            termux-notification --title "虚拟机启动失败" \
                --content "进程被终止, 检查保活设置" 2>/dev/null
            exit 1
        fi
        # 检测 VNC 端口就绪 = 桌面已起
        if (echo > /dev/tcp/127.0.0.1/5900) 2>/dev/null; then
            log "桌面已就绪 (用时约 $((N/60)) 分钟)"
            sleep 20   # 让它再稳定一会
            "$BASE_DIR/save_snapshot.sh" 2>>"$LOG" && touch "$SNAP"
            termux-notification --title "虚拟机就绪" \
                --content "冷启动完成, 快照已保存" --ongoing 2>/dev/null
            log "快照已保存, 下次将走秒级恢复"
            termux-wake-unlock 2>/dev/null
            exit 0
        fi
        sleep 10
        N=$((N+10))
    done
    log "[err] 超时未完成"
) &

log "=== autoboot 已完全转入后台 ==="
