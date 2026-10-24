#!/data/data/com.termux/files/usr/bin/bash
# 恢复 freemem_u36.sh deep 禁用的应用（需 root）
[ "$(id -u)" != "0" ] && { echo "[!] 需要 root"; exit 1; }
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
    com.android.video ; do
    pm enable "$p" 2>/dev/null && echo "已恢复: $p"
done
echo "完成"
