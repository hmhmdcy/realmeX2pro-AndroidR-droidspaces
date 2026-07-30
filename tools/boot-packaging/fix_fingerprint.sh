#!/system/bin/sh
# 修复自定义内核刷入后 "内部问题" 弹窗
# 原理：SELinux policy 阻止 vendor_init 设置 ro.build.fingerprint
# 用 resetprop 在开机阶段强制设置，绕过 SELinux 限制

# 从系统 build.prop 读取正确的 fingerprint
SYSTEM_FP=$(getprop ro.system.build.fingerprint)
VENDOR_FP=$(getprop ro.vendor.build.fingerprint)

# 优先使用 system 的 fingerprint，回退到 vendor 的
if [ -n "$SYSTEM_FP" ]; then
    TARGET_FP="$SYSTEM_FP"
elif [ -n "$VENDOR_FP" ]; then
    TARGET_FP="$VENDOR_FP"
else
    # 如果都取不到，用 ro.build.fingerprint 自身
    TARGET_FP=$(getprop ro.build.fingerprint)
fi

if [ -n "$TARGET_FP" ]; then
    # 强制设置所有相关 fingerprint 属性
    resetprop ro.build.fingerprint "$TARGET_FP"
    resetprop ro.bootimage.build.fingerprint "$TARGET_FP"
    resetprop ro.odm.build.fingerprint "$TARGET_FP"
    resetprop ro.vendor.build.fingerprint "$TARGET_FP"
    resetprop ro.system.build.fingerprint "$TARGET_FP"
fi
