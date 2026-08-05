#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL_DIR="${SCRIPT_DIR}/source"
KERNEL_OUT="${KERNEL_DIR}/out"
TOOLCHAIN_DIR="${SCRIPT_DIR}/toolchains"

CLANG_DIR="${CLANG_DIR:-${TOOLCHAIN_DIR}/clang-r433403b}"
GCC_DIR="${TOOLCHAIN_DIR}/aarch64-linux-android-4.9"
HOST_TOOLCHAIN="${TOOLCHAIN_DIR}/host-toolchain"
AARCH64_TOOLCHAIN="${TOOLCHAIN_DIR}/aarch64-toolchain"

export PATH="${CLANG_DIR}/bin:${GCC_DIR}/bin:${HOST_TOOLCHAIN}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HOST_TOOLCHAIN}/usr/lib/x86_64-linux-gnu:${HOST_TOOLCHAIN}/usr/lib:${AARCH64_TOOLCHAIN}/usr/lib/x86_64-linux-gnu"

export ARCH=arm64
export CROSS_COMPILE=${GCC_DIR}/bin/aarch64-linux-android-
export CC=${CLANG_DIR}/bin/clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export LD=${GCC_DIR}/bin/aarch64-linux-android-ld.bfd
export HOSTCC="${CLANG_DIR}/bin/clang --sysroot=${HOST_TOOLCHAIN}"

# These are passed directly to make (not exportable in bash due to hyphens)
HOSTLOADLIBES_EXTRACT="-lcrypto -lz -lzstd -ljitterentropy"
HOSTLOADLIBES_SIGN="-lcrypto -lz -lzstd -ljitterentropy"

# Fix OPlus broken include paths
if [ ! -L "${KERNEL_DIR}/kernel/msm-4.14" ]; then
  ln -sf "${KERNEL_DIR}" "${KERNEL_DIR}/kernel/msm-4.14"
fi

rm -rf ${KERNEL_OUT}
mkdir -p ${KERNEL_OUT}

echo "=== Defconfig ==="
make -C ${KERNEL_DIR} O=${KERNEL_OUT} \
  ARCH=arm64 CC="${CC}" CLANG_TRIPLE=${CLANG_TRIPLE} \
  HOSTCC="${HOSTCC}" LD="${LD}" CROSS_COMPILE=${CROSS_COMPILE} \
  vendor/realme_sm8150-perf_defconfig \
  HOSTLOADLIBES_extract-cert="${HOSTLOADLIBES_EXTRACT}" \
  HOSTLOADLIBES_sign-file="${HOSTLOADLIBES_SIGN}"

echo "=== Build kernel ==="
make -C ${KERNEL_DIR} O=${KERNEL_OUT} -j$(nproc) \
  ARCH=arm64 CC="${CC}" CLANG_TRIPLE=${CLANG_TRIPLE} \
  HOSTCC="${HOSTCC}" LD="${LD}" CROSS_COMPILE=${CROSS_COMPILE} \
  HOSTLOADLIBES_extract-cert="${HOSTLOADLIBES_EXTRACT}" \
  HOSTLOADLIBES_sign-file="${HOSTLOADLIBES_SIGN}"

echo "=== Compress kernel image ==="
gzip -c ${KERNEL_OUT}/arch/arm64/boot/Image > ${KERNEL_OUT}/arch/arm64/boot/Image.gz
# Note: AK3 uses Image (without appended DTB), matching stock KERNEL_FMT [raw].
# DTB is provided by boot.img's dtb section, preserved from stock.

echo "=== Done ==="
ls -lh ${KERNEL_OUT}/arch/arm64/boot/Image*
echo ""
echo "Build output: ${KERNEL_OUT}/arch/arm64/boot/"
