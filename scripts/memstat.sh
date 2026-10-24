#!/data/data/com.termux/files/usr/bin/bash
# 查看当前内存占用，以及 QEMU 实际吃多少
echo "=== 系统内存 ==="
free -m 2>/dev/null || cat /proc/meminfo | awk '/MemTotal|MemAvailable|MemFree|Buffers|Cached|SwapTotal|SwapFree/ {printf "%-14s %d MB\n", $1, $2/1024}'

echo
echo "=== 占用最多的前 12 个进程 ==="
ps -eo pid,rss,comm --sort=-rss 2>/dev/null | head -13 \
  | awk 'NR==1{printf "%-8s %-10s %s\n","PID","RSS(MB)","NAME"} NR>1{printf "%-8s %-10.1f %s\n",$1,$2/1024,$3}'

echo
echo "=== QEMU 进程 ==="
QPIDS=$(pgrep -f qemu-system 2>/dev/null)
if [ -z "$QPIDS" ]; then
    echo "  无 QEMU 在运行"
else
    TOTAL=0
    for p in $QPIDS; do
        RSS=$(awk '/VmRSS/{print $2}' /proc/$p/status 2>/dev/null)
        [ -z "$RSS" ] && RSS=0
        echo "  pid $p : $((RSS/1024)) MB"
        TOTAL=$((TOTAL + RSS/1024))
    done
    echo "  QEMU 总占用: ${TOTAL} MB"
    echo
    echo "  说明: QEMU 占用 = guest RAM + TCG 翻译缓存 + 软件 MMU"
    echo "        会比 -m 指定的 guest 内存多出约 120~250 MB，属正常"
fi
