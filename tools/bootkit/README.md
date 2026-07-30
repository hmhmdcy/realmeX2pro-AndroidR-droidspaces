# bootkit — Android boot.img 打包工具

bootkit 是一个自包含的 Android boot.img 打包工具集，可独立复制到任何项目中直接使用。

## 快速开始

```bash
# 最小用法（使用预设 assets）
./repack_boot.sh path/to/Image

# 完整用法
./repack_boot.sh \
  --device realme_x2pro \
  -c "console=ttyMSM0,115200n8 androidboot.hardware=qcom ..." \
  --dtb my.dtb --ramdisk my.ramdisk \
  kernel-Image \
  -o boot.img
```

## 参数

| 参数 | 说明 | 默认值 |
|---|---|---|
| `kernel` | 编译好的内核 Image（必填） | — |
| `ramdisk` | ramdisk 文件 | `assets/ramdisk.cpio.gz` |
| `dtb` | DTB 文件 | `assets/dtb` |
| `-c, --cmdline` | 内核 cmdline | 空 |
| `-o, --output` | 输出路径 | `../boot_new.img` |
| `--device <name>` | 加载 `conf/<name>.conf` 设备配置 | — |
| `--save-device <name>` | 保存当前参数为设备配置 | — |
| `-p, --page-size` | 页大小 | 4096 |
| `-b, --base` | 基地址 | 0x00000000 |
| `--kernel-offset` | 内核偏移 | 0x00008000 |
| `--ramdisk-offset` | ramdisk 偏移 | 0x01000000 |
| `--tags-offset` | tags 偏移 | 0x00000100 |
| `--dtb-offset` | DTB 偏移 | 0x00000000 |
| `-v, --header-version` | boot image header 版本 | 2 |
| `--os-version` | Android 版本 | 11.0.0 |
| `--os-patch-level` | 安全补丁日期 | 2021-11 |
| `--partition-size` | 分区大小（字节），填充到该大小 | 0（不填充） |

## 设备配置

在 `conf/` 下创建 `<device>.conf`，填入设备特定的打包参数：

```bash
# conf/my_device.conf
PAGE_SIZE=4096
BASE=0x00000000
KERNEL_OFFSET=0x00008000
RAMDISK_OFFSET=0x01000000
TAGS_OFFSET=0x00000100
DTB_OFFSET=0x00000000
HEADER_VERSION=2
OS_VERSION="11.0.0"
OS_PATCH_LEVEL="2021-11"
PARTITION_SIZE=100663296
```

使用配置：

```bash
./repack_boot.sh --device my_device -c "..." kernel-Image
```

保存当前命令行参数为配置：

```bash
./repack_boot.sh --save-device my_device -p 4096 -b 0x0 ...
```

## 复制到其他项目

```bash
# bootkit 不需要项目环境，直接拷贝
cp -r bootkit /path/to/other/project/

# 在目标项目中使用
/path/to/other/project/bootkit/repack_boot.sh \
  --device realme_x2pro \
  -c "..." kernel-Image
```

## 目录结构

```
bootkit/
├── repack_boot.sh          主脚本
├── mkbootimg.py            AOSP mkbootimg（Python）
├── gki/                    GKI 证书生成模块
├── assets/                 设备相关文件（每个设备不同）
│   ├── dtb                 设备树
│   └── ramdisk.cpio.gz     ramdisk
└── conf/                   设备配置
    ├── realme_x2pro.conf   Realme X2 Pro
    ├── sm8150.conf          SM8150 通用
    └── template.conf        新设备模板
```

## 输出

- 生成 `boot.img`（Android boot image header v0-v4）
- 自动验证 header 完整性
- 可选填充到指定分区大小

## 典型工作流

```bash
# 1. 编译内核
make -j4 Image

# 2. 打包
./repack_boot.sh \
  --device ${DEVICE} \
  -c "${CMDLINE}" \
  arch/arm64/boot/Image

# 3. 刷机
fastboot flash boot boot.img
fastboot reboot
```

## 依赖

- Python 3（`mkbootimg.py` 所需）
- 无其他外部依赖
