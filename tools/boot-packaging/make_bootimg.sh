#!/bin/bash
# boot.img 打包脚本 — Realme X2 Pro (SM8150)
# 使用 boot_assets/ 里的 ramdisk + dtb（从第一次成功的 boot.img 提取）
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
KERNEL_OUT="${PROJECT_DIR}/source/out"

# 参数（来自原厂 boot.img 分析）
BASE=0x00000000
PAGE_SIZE=4096
KERNEL_OFFSET=0x00008000
RAMDISK_OFFSET=0x01000000
TAGS_OFFSET=0x00000100
DTB_OFFSET=0x00000000
OS_VERSION=11.0.0
OS_PATCH_LEVEL=2021-11
CMDLINE="console=ttyMSM0,115200n8 earlycon=msm_geni_serial,0xa90000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 buildvariant=user"

# 内核（未压缩 Image，匹配原厂 KERNEL_FMT [raw]）
KERNEL="${KERNEL_OUT}/arch/arm64/boot/Image"
if [ ! -f "$KERNEL" ]; then
  echo "❌ 未找到编译产出 ${KERNEL}"
  echo "   请先运行 build.sh"
  exit 1
fi
echo "✅ 内核: ${KERNEL}"

# FolkPatch / KernelPatch 自动注入 (如果 kptools 存在)
KPTOOLS="${PROJECT_DIR}/tools/folkpatch/kptools-linux"
KPIMG="${PROJECT_DIR}/tools/folkpatch/kpimg-android"
SKEY="${FOLKPATCH_SKEY:-FolkPatch2026}"
PKG_NAME="${FOLKPATCH_PKG:-me.yuki.folk}"
CERT_SIGN="${FOLKPATCH_SIGN:-be9a9921cb475437d756cc11f9cd8096dd21ad512d3be6c6963ff9aa603e2ee1}"
KPATCH_BIN="${PROJECT_DIR}/tools/folkpatch/libkpatch.so"

if [ -x "$KPTOOLS" ] && [ -f "$KPIMG" ]; then
  echo ""
  echo "=== 注入 FolkPatch (Root-SuperKey: ${SKEY}, PKG: ${PKG_NAME}) ==="
  cp "$KPATCH_BIN" ./kpatch 2>/dev/null || true
  "$KPTOOLS" -p -i "$KERNEL" -k "$KPIMG" \
    -S "$SKEY" \
    -M ./kpatch -N kpatch -T exec \
    -a "pkg=${PKG_NAME}" \
    -a "sign=${CERT_SIGN}" \
    -o "${KERNEL_OUT}/arch/arm64/boot/Image-patched"
  rm -f ./kpatch
  KERNEL="${KERNEL_OUT}/arch/arm64/boot/Image-patched"
  echo "✅ 已完成 FolkPatch App 签名与 Exec 注入: ${KERNEL}"
fi

# Ramdisk（从已成功刷入的 boot.img 提取）
RAMDISK="${PROJECT_DIR}/boot_assets/ramdisk.cpio.gz"
if [ ! -f "$RAMDISK" ]; then
  echo "❌ 缺少 boot_assets/ramdisk.cpio.gz"
  echo "   从已成功的 boot.img 提取后放入 boot_assets/"
  echo "   python3 tools/extract_bootimg.py 成品boot.img boot_assets/"
  exit 1
fi
echo "✅ Ramdisk: ${RAMDISK}"

# DTB（从已成功刷入的 boot.img 提取，header v2）
DTB="${PROJECT_DIR}/boot_assets/dtb"
if [ -f "$DTB" ]; then
  DTB_ARG="--dtb ${DTB}"
  echo "✅ DTB: ${DTB}"
else
  DTB_ARG=""
  echo "⚠️  无 DTB 文件，跳过"
fi

echo ""
echo "=== 打包 boot.img ==="
python3 "${SCRIPT_DIR}/mkbootimg.py" \
  --kernel "$KERNEL" \
  --ramdisk "$RAMDISK" \
  ${DTB_ARG} \
  --base ${BASE} \
  --pagesize ${PAGE_SIZE} \
  --kernel_offset ${KERNEL_OFFSET} \
  --ramdisk_offset ${RAMDISK_OFFSET} \
  --tags_offset ${TAGS_OFFSET} \
  --dtb_offset ${DTB_OFFSET} \
  --os_version "${OS_VERSION}" \
  --os_patch_level "${OS_PATCH_LEVEL}" \
  --cmdline "${CMDLINE}" \
  --header_version 2 \
  -o "${PROJECT_DIR}/RealmeX2Pro-BOOT-folkpatch.img"

echo ""
echo "✅ boot.img 已生成: ${PROJECT_DIR}/RealmeX2Pro-BOOT-folkpatch.img"
ls -lh "${PROJECT_DIR}/RealmeX2Pro-BOOT-folkpatch.img"

# Pad 到 96MB（boot 分区大小，bootloader 校验完整分区）
BOOT_IMG="${PROJECT_DIR}/RealmeX2Pro-BOOT-folkpatch.img"
python3 -c "
with open('${BOOT_IMG}', 'ab') as f:
    f.truncate(100663296)
"
echo "✅ 已 pad 到 96MB (100663296)"
ls -lh "${BOOT_IMG}"

echo ""
echo "刷机：fastboot flash boot RealmeX2Pro-BOOT-folkpatch.img"
echo "  或：fastboot boot RealmeX2Pro-BOOT-folkpatch.img（临时启动测试）"
