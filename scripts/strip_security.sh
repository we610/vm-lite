#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# guest 镜像安全机制精简 —— 关闭不必要的防护以提速/简化
#
# 适用范围声明(重要):
#   本脚本仅用于【自建的、隔离的 guest 虚拟机镜像】。
#   guest 不承载真实个人数据, 且与宿主隔离, 故可安全精简。
#   请勿将这些操作施加于日常使用的真机。
#
# 核心原则:
#   能"关"的关掉; 不能"关"的(关了会崩)只降级为 permissive
# ============================================================

MODE=${1:-report}
KCFG=${KCFG:-./kernel.config}      # 内核 .config
FSTAB=${FSTAB:-./fstab}
INITRC=${INITRC:-./init.rc}

echo "=== guest 安全机制精简 (mode=$MODE) ==="
echo

# ---------- 分类清单 ----------
# [SAFE]  可直接关闭, 不影响启动
# [DOWN]  只能降级为 permissive/宽松, 完全删除会导致崩溃
# [KEEP]  建议保留(代价极小或删了收益为负)

declare -A ITEMS=(
  # ---- [SAFE] 可关 ----
  ["CONFIG_DM_VERITY"]="SAFE|分区完整性校验|关|省IO 13%, 改system免重签"
  ["CONFIG_MODULE_SIG"]="SAFE|内核模块签名|关|免签名, insmod 自编模块"
  ["CONFIG_MODULE_SIG_FORCE"]="SAFE|强制模块签名|关|同上"
  ["CONFIG_SECURITY_DMESG_RESTRICT"]="SAFE|dmesg访问限制|关|便于调试看内核日志"
  ["CONFIG_DEBUG_STRICT_USER_COPY_CHECKS"]="SAFE|用户拷贝检查|关|省CPU, 有性能开销"

  # ---- [DOWN] 只能降级 ----
  ["CONFIG_SECURITY_SELINUX"]="DOWN|SELinux强制访问控制|保留y+permissive|删了init会panic"
  ["CONFIG_SECURITY_SELINUX_DISABLE"]="DOWN|允许运行时禁用SELinux|不设|设了会让security_ops变NULL"
  ["randomize_va_space"]="DOWN|ASLR地址随机化|可设0|Android5.0强制, init.rc会写回2"

  # ---- [KEEP] 建议留 ----
  ["CONFIG_CC_STACKPROTECTOR"]="KEEP|栈保护|保留|几乎零开销, 删了易崩"
  ["CONFIG_HARDENED_USERCOPY"]="KEEP|用户拷贝加固|保留|同上"
)

for k in "${!ITEMS[@]}"; do
  IFS='|' read -r cat desc action note <<<"${ITEMS[$k]}"
  printf "  [%-4s] %-42s %-18s %s\n" "$cat" "$k" "$action" "$note"
done | sort

echo
echo "--- 图例 ---"
echo "  SAFE = 可直接关闭   DOWN = 只能降级(删了会崩)   KEEP = 建议保留"
echo

[ "$MODE" = "report" ] && exit 0

# ---------- 执行模式 ----------
if [ ! -f "$KCFG" ]; then echo "[X] 找不到 $KCFG"; exit 1; fi

echo "=== 应用内核配置改动 ==="
for k in "${!ITEMS[@]}"; do
  IFS='|' read -r cat desc action note <<<"${ITEMS[$k]}"
  [ "$cat" != "SAFE" ] && continue
  case "$k" in
    CONFIG_*)
      # 已有则改, 没有则追加
      if grep -q "^$k=" "$KCFG"; then
        sed -i "s|^$k=.*|$k=n|" "$KCFG"
        echo "  $k=n  (已修改)"
      else
        echo "$k=n" >> "$KCFG"
        echo "  $k=n  (已追加)"
      fi
      ;;
  esac
done

echo
echo "=== SELinux: 保留框架, 降级为 permissive ==="
echo "  [!] 切勿在内核里禁用 SELinux。"
echo "      内核禁用 -> security_ops 置 NULL -> security_setprocattr() panic"
echo "      且 init 的 setcon(\"u:r:init:s0\") 返回 -1 -> early init abort"
echo "  正确做法: 保持 CONFIG_SECURITY_SELINUX=y, 用启动参数降级"
echo
echo "  请在 boot.img cmdline 加入:"
echo "    androidboot.selinux=permissive"
echo
echo "  (build_boot.sh 的 CMDLINE 已含此项, 确认即可)"

echo
echo "=== fstab: 确认无 verify 标志 ==="
if [ -f "$FSTAB" ]; then
  if grep -q "verify" "$FSTAB"; then
    echo "  [!] fstab 仍含 verify 标志 -> 会 bootloop"
    grep -n "verify" "$FSTAB"
  else
    echo "  OK: 无 verify 标志"
  fi
else
  echo "  跳过(未找到 $FSTAB)"
fi

echo
echo "=== 完成 ==="
echo "  改完 .config 后需重新编译内核: make oldconfig && make"
