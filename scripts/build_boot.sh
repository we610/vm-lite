#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# 打包 boot.img —— 三分区方案
#   boot.img  = kernel(zImage) + ramdisk(最小 initramfs) + dtb
#   system    = 独立分区, ext4, 走 virtio-blk, 按需分页
#   userdata  = 独立分区, ext4
#
# 关键: ramdisk 只做「挂载工」, 不塞 system
#       塞了会把 250MB+ 压进运存, guest 512MB 直接爆
# ============================================================

set -e

# ---------- 可配置项 ----------
KERNEL=${KERNEL:-./zImage}                 # ARM32 zImage (7.9 定档)
RAMDISK=${RAMDISK:-./ramdisk.cpio.gz}      # 最小 initramfs, 8~40MB
DTB=${DTB:-}                               # 可选
OUT=${OUT:-./boot.img}

# boot.img header 布局 (ARM32 virt 常见值)
BASE=${BASE:-0x10000000}
KERNEL_OFFSET=${KERNEL_OFFSET:-0x00008000}
RAMDISK_OFFSET=${RAMDISK_OFFSET:-0x01000000}
TAGS_OFFSET=${TAGS_OFFSET:-0x00000100}
PAGE_SIZE=${PAGE_SIZE:-4096}

# 内核 cmdline: 关校验, 指定 root
# 注意: root= 必须指向 system 所在的块设备
CMDLINE=${CMDLINE:-"console=ttyAMA0 root=/dev/vda rootfstype=ext4 ro androidboot.selinux=permissive"}

# ---------- 校验输入 ----------
[ -f "$KERNEL" ]  || { echo "[X] 找不到内核: $KERNEL"; exit 1; }
[ -f "$RAMDISK" ] || { echo "[X] 找不到 ramdisk: $RAMDISK"; exit 1; }

# 体积检查: ramdisk 超过 64MB 说明塞了不该塞的东西
RDSIZE=$(( $(stat -c%s "$RAMDISK") / 1024 / 1024 ))
echo "kernel : $(stat -c%s "$KERNEL") bytes"
echo "ramdisk: ${RDSIZE} MB"
if [ "$RDSIZE" -gt 64 ]; then
    echo
    echo "[!] ramdisk 超过 64MB (${RDSIZE}MB)"
    echo "    ramdisk 启动时整体载入 RAM 且常驻, 吃的是运存不是磁盘"
    echo "    多半是把 system 塞进去了 —— 请移回独立 system 分区"
    read -r -p "    仍要继续? [y/N] " yn
    [ "$yn" = "y" ] || exit 1
fi

# ---------- 打包 ----------
MKBOOTIMG=${MKBOOTIMG:-mkbootimg}

echo
echo "打包 boot.img ..."
"$MKBOOTIMG" \
    --kernel       "$KERNEL" \
    --ramdisk      "$RAMDISK" \
    ${DTB:+--dtb "$DTB"} \
    --base         "$BASE" \
    --kernel_offset  "$KERNEL_OFFSET" \
    --ramdisk_offset "$RAMDISK_OFFSET" \
    --tags_offset  "$TAGS_OFFSET" \
    --pagesize     "$PAGE_SIZE" \
    --cmdline      "$CMDLINE" \
    --output       "$OUT"

echo "完成: $OUT ($(stat -c%s "$OUT") bytes)"
echo
echo "=== 启动前自查(起不来多半是这几条) ==="
echo "  1. 内核是否静态编入 virtio-blk?  zcat /proc/config.gz | grep VIRTIO_BLK"
echo "     -> 没有的话 ramdisk 起完找不到 system, 直接 panic"
echo "  2. 存储控制器 + EXT4 是否静态编入? (7.5 保命约束)"
echo "  3. CONFIG_MODULES=y 是否开启? (7.22, 否则 insmod 废)"
echo "  4. fstab 是否残留 verify 标志? (已关 dm-verity 却留标志 -> bootloop)"
