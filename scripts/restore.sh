#!/data/data/com.termux/files/usr/bin/bash
# 恢复: 把 freemem.sh deep 模式禁用的应用重新启用
# 用法: bash restore.sh   （需要 root）

if [ "$(id -u)" != "0" ]; then
    echo "[!] 需要 root"
    exit 1
fi

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
    pm enable "$pkg_name" 2>/dev/null && echo "已恢复: $pkg_name"
done
echo "完成"
