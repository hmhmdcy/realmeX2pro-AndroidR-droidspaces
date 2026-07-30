# Realme X2 Pro (SM8150) Android R Kernel — DroidSpaces

Custom kernel for Realme X2 Pro (RMX1931/samurai) based on Android R (kernel 4.14.190-perf+) with **DroidSpaces** container support.

## Branches

| Branch | Description |
|--------|-------------|
| `master` | **Merged Main Branch**: Contains DroidSpaces container support, production-grade Panic Logstore, and FolkPatch Kernel Root |
| `feat/droidspaces` | DroidSpaces container support (configs, cgroup fix, MODVERSIONS bypass) |
| `feat/minidump-ramoops` | Minidump registration for ramoops persistence |
| `feat/panic-logstore` | **panic_logstore**: dump kernel log to `/cache/last_panic.log` during panic via VFS write |

## Prerequisites — Toolchains

Place toolchains under `toolchains/`:

- `clang-r383902/` — AOSP Clang
- `aarch64-linux-android-4.9/` — GCC cross-compiler
- `host-toolchain/` — Host compilation libraries (libcrypto, libz, etc.)
- `aarch64-toolchain/` — Additional aarch64 host libraries

## Build

```bash
# 1. Full build (defconfig + compile)
bash build.sh

# 2. Package as AK3 flashable zip
bash tools/boot-packaging/make_anykernel3.sh
```

Output: `RealmeX2Pro-AK3.zip` (anykernel3 zip — flash in TWRP/OrangeFox) and `RealmeX2Pro-BOOT-folkpatch.img` (fastboot image).

## Project Layout

```
├── build.sh                           # Build entry point
├── source/                            # Kernel source tree
│   ├── arch/arm64/configs/vendor/
│   │   └── realme_sm8150-perf_defconfig
│   └── ...
├── toolchains/                        # Compilers (not included)
├── tools/
│   ├── boot-packaging/                # AK3 packaging, boot.img tools
│   │   ├── anykernel3/                # AnyKernel3 template
│   │   ├── make_anykernel3.sh         # Package AK3 zip
│   │   ├── make_bootimg.sh            # Build boot.img directly
│   │   └── extract_bootimg.py         # Extract stock boot.img
│   ├── pstore-blk-research.md         # pstore/blk backport research notes
│   └── realme-x2-pro-9008-recovery.md # EDL unbrick guide
```

## DroidSpaces Features

Enabled via `feat/droidspaces` branch:

- **Namespaces**: PID, UTS, IPC, NET, USER
- **Cgroups**: device, pids, scheduler, freezer, net_prio
- **Networking**: veth, bridge, nftables, netfilter (NAT/masquerade/conntrack)
- **Seccomp**: filter support
- **Filesystem**: overlayfs, devtmpfs, tmpfs xattr/ACL
- **MODVERSIONS bypass**: vendor modules load without CRC match

## Flash

1. Boot TWRP or OrangeFox recovery
2. Flash `RealmeX2Pro-AK3.zip`
3. (Optional) For Magisk compatibility — flash Magisk *after* the kernel zip, or patch stock boot.img then flash kernel

## Tools

- `tools/boot-packaging/extract_bootimg.py` — extract stock boot.img for DTB/cmdline reference
- `tools/boot-packaging/make_bootimg.sh` — pack a raw boot.img (for EDL flash)
- `tools/realme-x2-pro-9008-recovery.md` — unbrick via EDL 9008 mode

## panic_logstore (崩溃日志持久化引擎)

On devices where the bootloader clears DDR on reboot (Realme X2 Pro), ramoops/pstore is cleared.

**panic_logstore** writes the kernel log to a persistent filesystem file during panic:

- **Path**: `/cache/last_panic.log` (pre-mounted ext4, survives reboot)
- **Trigger**: auto in `panic()`, or manually via `echo 1 > /sys/module/panic_logstore/parameters/trigger`
- **Optimizations**: Batch single write (`kmsg_dump_get_buffer`), atomic re-entrancy guard, pre-allocated root creds, and structured summary header.

### 读取日志

```bash
# 正常启动后
adb shell "su -c 'tail -n 30 /cache/last_panic.log'"

# 导出到电脑
adb pull /cache/last_panic.log C:\Users\cy122\Desktop\last_panic.log
```

## FolkPatch (内核 Root 接口)

The kernel is automatically patched with **FolkPatch / KernelPatch** during boot packaging (`make_bootimg.sh` & `make_anykernel3.sh`):

- **App Package**: `me.yuki.folk` (Signature Hash Bound)
- **SuperKey**: `FolkPatch2026`
- **Usage**: Install [FolkPatch.apk](https://github.com/LyraVoid/FolkPatch/releases/latest), open the app, and enter `FolkPatch2026` to unlock Root!
