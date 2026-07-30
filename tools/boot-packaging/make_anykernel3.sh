#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
KERNEL_OUT="${PROJECT_DIR}/source/out"
AK3_DIR="${SCRIPT_DIR}/anykernel3"
OUTPUT="${PROJECT_DIR}/RealmeX2Pro-AK3.zip"

KERNEL="${KERNEL_OUT}/arch/arm64/boot/Image"
if [ ! -f "$KERNEL" ]; then
  KERNEL="${KERNEL_OUT}/arch/arm64/boot/Image.gz"
fi
if [ ! -f "$KERNEL" ]; then
  echo "❌ 未找到内核编译产出"
  exit 1
fi
echo "✅ 内核: $KERNEL"

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

# 清空 AnyKernel3 自带的内核占位
rm -f "${AK3_DIR}/Image" "${AK3_DIR}/Image.gz" "${AK3_DIR}/Image.gz-dtb" "${AK3_DIR}/zImage"

# 复制内核（不带 appended DTB，DTB 由 boot.img 的 dtb section 提供）
# 使用未压缩 Image 以匹配原厂 boot.img 的 KERNEL_FMT [raw]
cp "$KERNEL" "${AK3_DIR}/Image"

# 更新 anykernel.sh 中的设备名（Realme X2 Pro 代号 samurai / RMX1931）
sed -i 's/^device.name1=.*/device.name1=RMX1931/' "${AK3_DIR}/anykernel.sh" 2>/dev/null || true
sed -i 's/^device.name2=.*/device.name2=rmx1931/' "${AK3_DIR}/anykernel.sh" 2>/dev/null || true
sed -i 's/^device.name3=.*/device.name3=samurai/' "${AK3_DIR}/anykernel.sh" 2>/dev/null || true
sed -i 's/^device.name4=.*/device.name4=Realme X2 Pro/' "${AK3_DIR}/anykernel.sh" 2>/dev/null || true

cd "${AK3_DIR}"
python3 -c "
import zipfile, os
with zipfile.ZipFile('${OUTPUT}', 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk('.'):
        if '.git' in root: continue
        for f in files:
            path = os.path.join(root, f)
            arcname = os.path.relpath(path, '.')
            z.write(path, arcname)
"

echo ""
echo "✅ 刷机包已生成: ${OUTPUT}"
ls -lh "${OUTPUT}"
echo ""
echo "刷机：在 TWRP/OrangeFox 中刷入 RealmeX2Pro-AK3.zip"
