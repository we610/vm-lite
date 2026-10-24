#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# SystemServer 服务裁剪 —— 冷启动最大瓶颈(7.4 已标注)
#
# 收益: 约 17% 冷启动提速(自多核以来最大单项)
#
# 三种裁剪手段(按推荐顺序):
#   [1] disableNonCoreServices 标志  <- Android 5.0 原生开关, 最省事
#   [2] hasSystemFeature 特性声明    <- 改 XML, 不用改 Java
#   [3] 注释 startService            <- 最直接, 但需重编 framework
# ============================================================

MODE=${1:-report}
SS=${SS:-./SystemServer.java}
PERM=${PERM:-./permissions}

echo "=== Android 5.0 SystemServer 三阶段 ==="
cat <<'TAB'
  startBootstrapServices  <- 必须保留(有复杂相互依赖)
    Installer, ActivityManagerService, PowerManagerService,
    DisplayManagerService, PackageManagerService, UserManagerService

  startCoreServices       <- 必须保留(数量少, 仅 4 个)
    LightsService, BatteryService, UsageStatsService,
    WebViewUpdateService

  startOtherServices      <- 数十个杂项, 主要裁剪对象
TAB
echo
echo "=== startOtherServices 裁剪清单 ==="
echo
echo "  [保留] 这 5 个不能动:"
for s in WindowManagerService InputManagerService MountService \
         NetworkManagementService ConnectivityService; do
  echo "    + $s"
done
echo
echo "  [可裁] 这 16 个 (虚拟机里没对应硬件或不需要):"
for s in BluetoothManagerService TelephonyRegistry NsdService \
         NetworkScoreService SerialService ConsumerIrService \
         VibratorService CommonTimeManagementService \
         NetworkTimeUpdateService UsbService AccountManagerService \
         ContentService DreamManagerService PrintManagerService \
         FingerprintService NfcService; do
  echo "    - $s"
done
echo

[ "$MODE" = "report" ] && {
cat <<'NOTE'
--- 三种裁剪手段 ---

[1] disableNonCoreServices 标志 (推荐, 最省事)
    Android 5.0 的 startOtherServices() 里原生就有这个标志。
    置位后大量非核心服务直接跳过, 无需逐个改代码。
    搜 SystemServer.java 里的 disableNonCoreServices 并设为 true。

[2] hasSystemFeature 特性声明 (改 XML, 不用改 Java)
    很多服务用 hasSystemFeature() 判断是否启动。
    删掉 /system/etc/permissions/ 下对应 XML 里的特性声明,
    服务就不会启动。例: 打印服务需要 android.software.print。
    常用特性文件: handheld_core_hardware.xml

[3] 注释 startService (最直接)
    注释掉 mSystemServiceManager.startService(XXX.class)
    需重新编译 framework, 但控制最精确。

--- 三条铁律 ---
1. bootstrap 服务一个都不能动 —— 它们有复杂相互依赖
2. 删服务前先确认没有别的组件依赖它, 否则运行时崩溃
3. 优先用手段[1]和[2], 能不改 Java 就不改

--- 延迟加载(比删除更稳妥) ---
不想删的服务, 可以推迟到 BOOT_COMPLETED 之后再起:
    mHandler.postDelayed(() -> startDelayedServices(), 5000);
把非首屏必需的服务移出启动关键路径。
NOTE
exit 0; }

# ---------- apply 模式: 手段[3], 注释 startService ----------
[ -f "$SS" ] || { echo "[X] 找不到 $SS"; exit 1; }

echo "=== 应用: 注释可裁服务的 startService ==="
cp "$SS" "${SS}.bak" && echo "  已备份 -> ${SS}.bak"

CUT_LIST="BluetoothManagerService TelephonyRegistry NsdService \
NetworkScoreService SerialService ConsumerIrService VibratorService \
CommonTimeManagementService NetworkTimeUpdateService UsbService \
AccountManagerService ContentService DreamManagerService \
PrintManagerService FingerprintService NfcService"

N=0
for svc in $CUT_LIST; do
  # 匹配 startService(XxxService.class) 并注释
  if grep -qE "startService\(([A-Za-z.]*\.)?${svc}\.class\)" "$SS"; then
    sed -i -E "s|^([[:space:]]*)(.*startService\(([A-Za-z.]*\.)?${svc}\.class\).*)$|\1// [VM-LITE-CUT] \2|" "$SS"
    echo "  已注释: $svc"
    N=$((N+1))
  else
    echo "  未找到: $svc (可能写法不同, 请手动确认)"
  fi
done

echo
echo "  共注释 $N 个服务"
echo
echo "=== 下一步 ==="
echo "  1. 重编 framework: mmm frameworks/base"
echo "  2. 若启动崩溃, 用 ${SS}.bak 回滚"
echo "  3. 优先确认 disableNonCoreServices 是否已置位(手段[1]更省事)"
