# Realme X2 Pro (SM8150) Android R Kernel — DroidSpaces

Custom kernel for Realme X2 Pro (RMX1931/samurai) based on Android R (kernel 4.14.190-perf+) with **DroidSpaces** container support.

### Kernel source (内核来源)

This project builds on the official Realme kernel source for Realme X2 Pro:

- **容器内核补丁说明**: [`source/CONTAINER-ROOTLESS-PATCHES.md`](source/CONTAINER-ROOTLESS-PATCHES.md) — rootless Podman 7 关卡补丁链、安全边界、实测结论（overlay 存储不可行原因、`--cgroups=disabled` 必要、镜像加速配置）

- **Upstream**: [realme-kernel-opensource/realmeX2pro-X3-AndroidR-kernel-source](https://github.com/realme-kernel-opensource/realmeX2pro-X3-AndroidR-kernel-source) — Android R (kernel 4.14.190-perf+), base commit `23172a157`
- **Fork**: [hmhmdcy/realmeX2pro-X3-AndroidR-kernel-source](https://github.com/hmhmdcy/realmeX2pro-X3-AndroidR-kernel-source) — all custom branches (see below) live here; linked via git submodule
- **AnyKernel3**: [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) → fork [hmhmdcy/AnyKernel3](https://github.com/hmhmdcy/AnyKernel3) (RMX1931 device config), used by `tools/boot-packaging/make_anykernel3.sh`
- **GCC 4.9**: [LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9](https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9)

### Clone with submodules

```bash
git clone --recursive https://github.com/hmhmdcy/realmeX2pro-AndroidR-droidspaces.git
# or, if already cloned without submodules:
git submodule update --init --recursive
```

## Branches

| Branch | Description |
|--------|-------------|
| `feat/container-networking` | **Current mainline (verified working)**: all DroidSpaces + panic_logstore + full container/LXC/Kali enhancements. This is the branch to build and flash. |
| `feat/cgroup-v2-freezer` | **Working branch** (this repo's submodule pin): currently identical to `feat/container-networking` at `076a14b76`. |
| `master` | Release line: DroidSpaces + panic_logstore (superset relationship: `feat/container-networking` ⊇ `master`). |
| `feat/droidspaces` | **Migrated from upstream DroidSpaces project** (archive): base container configs, cgroup fix, MODVERSIONS bypass. |
| `feat/panic-logstore` | **Migrated from OnePlus SM8550 kernel** (archive): panic log persistence to `/cache/last_panic.log`. Identical to `master`. |
| `feat/minidump-ramoops` | **DEPRECATED / abandoned** — no content beyond baseline. Do not use. |

### Feature matrix

| Feature | droidspaces | master | container-networking |
|---|---|---|---|
| DroidSpaces base (namespaces/cgroups/seccomp/overlayfs/NAT) | ✅ | ✅ | ✅ |
| MODVERSIONS CRC bypass (vendor modules) | ✅ | ✅ | ✅ |
| panic_logstore (`/cache/last_panic.log`) | — | ✅ | ✅ |
| Container NICs: MACVLAN/MACVTAP/VXLAN/GENEVE | — | — | ✅ |
| IPv6 NAT, NET_CLS_CGROUP, XT_MATCH_CGROUP, IP_MROUTE | — | — | ✅ |
| LXC: FHANDLE, CHECKPOINT_RESTORE, AUTOFS4, SQUASHFS, HUGETLBFS, CGROUP_PERF, BLK_DEV_THROTTLING | — | — | ✅ |
| nftables full expression set (37 opts) | — | — | ✅ |
| overlayfs redirect_dir/index, ipset all types, binfmt_misc | — | — | ✅ |
| IPVLAN/IPVTAP | — | — | ❌ removed (breaks prebuilt wlan.ko ABI — see commit 076a14b76) |

## Prerequisites — Toolchains

Place toolchains under `toolchains/`:

- `clang-r433403b/` — AOSP Clang 13.0.3 (default; `CLANG_DIR` 环境变量可覆盖回 `clang-r383902/` Clang 11.0.1)
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
├── source/                            # Kernel source tree (git submodule)
│   ├── arch/arm64/configs/vendor/
│   │   └── realme_sm8150-perf_defconfig
│   └── ...
├── toolchains/                        # Compilers (vendored in this repo)
├── tools/
│   ├── boot-packaging/                # AK3 packaging, boot.img tools
│   │   ├── anykernel3/                # AnyKernel3 template (git submodule)
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
