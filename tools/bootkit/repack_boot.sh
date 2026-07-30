#!/bin/bash
#
# repack_boot.sh — 通用 Android boot.img 打包工具
#
# 本目录包含所有依赖，复制到任何位置即可使用。
#
# 用法:
#   ./repack_boot.sh <kernel>                          # 使用预设的 ramdisk+dtb
#   ./repack_boot.sh <kernel> <ramdisk> <dtb>           # 自定义组件
#   ./repack_boot.sh --device <name> <kernel>           # 使用设备配置
#   ./repack_boot.sh --save-device <name> [args]        # 保存设备配置
#
# 参数:
#   -c, --cmdline        内核 cmdline
#   -p, --page-size      page size（默认 4096）
#   -b, --base           基地址（默认 0x00000000）
#       --kernel-offset  内核偏移（默认 0x00008000）
#       --ramdisk-offset ramdisk 偏移（默认 0x01000000）
#       --tags-offset    tags 偏移（默认 0x00000100）
#       --dtb-offset     DTB 偏移（默认 0x00000000）
#   -v, --header-version header 版本（默认 2）
#       --os-version     Android 版本（默认 11.0.0）
#       --os-patch-level 安全补丁日期（默认 2021-11）
#       --partition-size 分区大小（字节），填充到此大小
#       --dtb            DTB 文件路径
#       --ramdisk        ramdisk 文件路径
#       --device         加载设备配置
#       --save-device    保存当前参数为设备配置
#   -o, --output         输出路径（默认 ../boot_new.img）
#   -h, --help           显示此帮助
#

set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
MKBOOTIMG="$KIT_DIR/mkbootimg.py"

# 默认查找 assets/
if [ -d "$KIT_DIR/assets" ]; then
  : ${RAMDISK:="$KIT_DIR/assets/ramdisk.cpio.gz"}
  : ${DTB:="$KIT_DIR/assets/dtb"}
fi

# ── 默认值 ──────────────────────────────────────────────
PAGE_SIZE=4096
BASE=0x00000000
KERNEL_OFFSET=0x00008000
RAMDISK_OFFSET=0x01000000
TAGS_OFFSET=0x00000100
DTB_OFFSET=0x00000000
HEADER_VERSION=2
OS_VERSION="11.0.0"
OS_PATCH_LEVEL="2021-11"
PARTITION_SIZE=0
CMDLINE=""
OUTPUT=""

# ── 加载设备配置 ──────────────────────────────────────────
load_config() {
  local cfg="$KIT_DIR/conf/$1.conf"
  if [ -f "$cfg" ]; then
    source "$cfg"
    echo "  Config: $1"
  fi
}

save_config() {
  mkdir -p "$KIT_DIR/conf"
  local cfg="$KIT_DIR/conf/$1.conf"
  cat > "$cfg" << EOFC
# Device config: $1
PAGE_SIZE=$PAGE_SIZE
BASE=$BASE
KERNEL_OFFSET=$KERNEL_OFFSET
RAMDISK_OFFSET=$RAMDISK_OFFSET
TAGS_OFFSET=$TAGS_OFFSET
DTB_OFFSET=$DTB_OFFSET
HEADER_VERSION=$HEADER_VERSION
OS_VERSION="$OS_VERSION"
OS_PATCH_LEVEL="$OS_PATCH_LEVEL"
PARTITION_SIZE=$PARTITION_SIZE
EOFC
  echo "  Config saved: $1"
}

# ── 参数解析 ──────────────────────────────────────────────
POS_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -c|--cmdline)        CMDLINE="$2"; shift 2 ;;
    -p|--page-size)      PAGE_SIZE="$2"; shift 2 ;;
    -b|--base)           BASE="$2"; shift 2 ;;
    --kernel-offset)     KERNEL_OFFSET="$2"; shift 2 ;;
    --ramdisk-offset)    RAMDISK_OFFSET="$2"; shift 2 ;;
    --tags-offset)       TAGS_OFFSET="$2"; shift 2 ;;
    --dtb-offset)        DTB_OFFSET="$2"; shift 2 ;;
    -v|--header-version) HEADER_VERSION="$2"; shift 2 ;;
    --os-version)        OS_VERSION="$2"; shift 2 ;;
    --os-patch-level)    OS_PATCH_LEVEL="$2"; shift 2 ;;
    --partition-size)    PARTITION_SIZE="$2"; shift 2 ;;
    --dtb)               DTB="$2"; shift 2 ;;
    --ramdisk)           RAMDISK="$2"; shift 2 ;;
    -o|--output)         OUTPUT="$2"; shift 2 ;;
    --device)            load_config "$2"; shift 2 ;;
    --save-device)       SAVE_DEVICE="$2"; shift 2 ;;
    -h|--help)           sed -n '2,30p' "$0"; exit 0 ;;
    *)                   POS_ARGS+=("$1"); shift ;;
  esac
done

KERNEL="${POS_ARGS[0]:-}"
RAMDISK="${RAMDISK:-${POS_ARGS[1]:-}}"
DTB="${DTB:-${POS_ARGS[2]:-}}"
OUTPUT="${OUTPUT:-${POS_ARGS[3]:-$(dirname "$KIT_DIR")/boot_new.img}}"

# ── 保存配置模式 ──────────────────────────────────────────
if [ -n "${SAVE_DEVICE:-}" ]; then
  save_config "$SAVE_DEVICE"
  exit 0
fi

# ── 验证 ──────────────────────────────────────────────────
if [ -z "$KERNEL" ]; then
  echo "Usage: $0 [options] <kernel> [ramdisk] [dtb] [output]"
  echo "Try:   $0 --help"
  exit 1
fi

[ ! -f "$MKBOOTIMG" ] && { echo "ERROR: mkbootimg.py not found at $MKBOOTIMG"; exit 1; }
[ ! -f "$KERNEL" ] && { echo "ERROR: kernel not found: $KERNEL"; exit 1; }

if [ -n "$RAMDISK" ] && [ ! -f "$RAMDISK" ]; then
  echo "Warning: ramdisk not found: $RAMDISK (skip)"
  RAMDISK=""
fi
if [ -n "$DTB" ] && [ ! -f "$DTB" ]; then
  echo "Warning: dtb not found: $DTB (skip)"
  DTB=""
fi

# header v2+ requires dtb
if [ "$HEADER_VERSION" -ge 2 ] && [ -z "$DTB" ]; then
  echo "ERROR: header v$HEADER_VERSION requires --dtb"
  exit 1
fi

# ── 信息 ──────────────────────────────────────────────────
KERNEL_SZ=$(stat -c%s "$KERNEL")
echo "== boot.img packer =="
echo "Kernel:   $KERNEL ($((KERNEL_SZ / 1048576)) MB)"
echo "Ramdisk:  ${RAMDISK:-<none>}"
echo "DTB:      ${DTB:-<none>}"
echo "Header:   v$HEADER_VERSION"
echo ""

# ── 构建参数 ──────────────────────────────────────────────
ARGS=(--kernel "$KERNEL")
[ -n "$RAMDISK" ] && ARGS+=(--ramdisk "$RAMDISK")
[ -n "$DTB" ]     && ARGS+=(--dtb "$DTB")
[ -n "$CMDLINE" ] && ARGS+=(--cmdline "$CMDLINE")
ARGS+=(--base "$BASE" --pagesize "$PAGE_SIZE")
ARGS+=(--kernel_offset "$KERNEL_OFFSET" --ramdisk_offset "$RAMDISK_OFFSET")
ARGS+=(--tags_offset "$TAGS_OFFSET" --dtb_offset "$DTB_OFFSET")
ARGS+=(--os_version "$OS_VERSION" --os_patch_level "$OS_PATCH_LEVEL")
ARGS+=(--header_version "$HEADER_VERSION" -o "$OUTPUT")

# ── 执行 ──────────────────────────────────────────────────
python3 "$MKBOOTIMG" "${ARGS[@]}"

# ── 验证 ──────────────────────────────────────────────────
python3 -c "
import struct
with open('$OUTPUT', 'rb') as f:
    hdr = f.read(2048)
magic = hdr[0:8].decode()
assert magic == 'ANDROID!', 'Not a valid boot image'
ks = struct.unpack_from('<I', hdr, 0x08)[0]
rs = struct.unpack_from('<I', hdr, 0x10)[0]
print(f'  Magic: {magic}')
print(f'  Kernel: {ks//1024} KB | Ramdisk: {rs//1024} KB')
print(f'  OK: $OUTPUT')
"

# ── 填充 ──────────────────────────────────────────────────
if [ "$PARTITION_SIZE" -gt 0 ]; then
  SZ=$(stat -c%s "$OUTPUT")
  if [ "$SZ" -lt "$PARTITION_SIZE" ]; then
    python3 -c "with open('$OUTPUT', 'ab') as f: f.truncate($PARTITION_SIZE)"
    echo "  Padded: $((PARTITION_SIZE / 1048576)) MB"
  fi
fi

echo "  Done: $(ls -lh "$OUTPUT" | awk '{print $5}')"
