#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# zygote + ART 内存调优 —— 针对 guest 仅保留 3 个轻量应用
#
# 诚实前提(先看这条):
#   dalvik.vm.heapsize 是【上限】不是【预分配】。
#   ART 按需增长, 不会启动时就吃掉全部上限。
#   所以调小 heapsize【不直接省常驻内存】, 只限制峰值。
#   真正省常驻的是: 预加载类数量 与 堆的实际使用量。
# ============================================================

MODE=${1:-report}
PROP=${PROP:-./build.prop}       # 或 /system/build.prop

# ---------- 当前构成(供对照) ----------
echo "=== zygote + ART 当前构成(约 90MB) ==="
cat <<'TAB'
   48MB  ART 堆 (dalvik.vm.heapsize)   <- 上限, 非预分配
   26MB  预加载类 (preloaded-classes)  <- 已在 7.1 砍至数百
   10MB  zygote 进程自身开销           <- 基本不可调
    6MB  AOT .oat 映射                 <- 提前 dex2oat, 属必要
TAB
echo

# ---------- 推荐档位 ----------
echo "=== heapsize 档位(三选一) ==="
cat <<'TAB'
  档位    growthlimit   heapsize   适用
  ----    -----------   --------   ----
  宽松    128m          256m       默认, 稳妥
  适中     96m          128m       推荐(3个轻量应用够用)
  紧凑     64m           96m       下限, 再低会频繁 GC
TAB
echo

[ "$MODE" = "report" ] && {
cat <<'NOTE'
--- 重要说明 ---
1. 调小 heapsize 不省常驻内存, 只防峰值失控
2. 真正省内存的是砍 preloaded-classes(7.1 已做)
3. 堆太小 -> 频繁 GC -> TCG 下 GC 开销被放大 -> 更卡
4. 建议下限: growthlimit 64m / heapsize 96m
NOTE
exit 0; }

# ---------- 应用模式 ----------
LEVEL=${2:-medium}
case "$LEVEL" in
  loose)  GL=128m; HS=256m ;;
  medium) GL=96m;  HS=128m ;;
  tight)  GL=64m;  HS=96m  ;;
  *) echo "[X] 档位只能是 loose|medium|tight"; exit 1 ;;
esac

[ -f "$PROP" ] || { echo "[X] 找不到 $PROP"; exit 1; }

echo "=== 应用档位: $LEVEL (growthlimit=$GL heapsize=$HS) ==="

set_prop() {
  local k=$1 v=$2
  if grep -q "^$k=" "$PROP"; then
    sed -i "s|^$k=.*|$k=$v|" "$PROP"; echo "  $k=$v  (已修改)"
  else
    echo "$k=$v" >> "$PROP";     echo "  $k=$v  (已追加)"
  fi
}

set_prop dalvik.vm.heapgrowthlimit   "$GL"
set_prop dalvik.vm.heapsize          "$HS"

# 与堆相关的配套项(同样只影响峰值/策略, 不省常驻)
set_prop dalvik.vm.heapstartsize       "8m"
set_prop dalvik.vm.heapmaxfree         "8m"
set_prop dalvik.vm.heapminfree         "512k"
set_prop dalvik.vm.heaptargetutilization "0.75"

echo
echo "=== 完成 ==="
echo "  改动的是【上限与GC策略】, 常驻内存节省有限。"
echo "  若想真正降低基线, 应回到 7.1 的 preloaded-classes 裁剪,"
echo "  而非在 heapsize 上做文章。"
echo
echo "  验证: 启动后执行"
echo "    getprop dalvik.vm.heapsize"
echo "    dumpsys meminfo"
