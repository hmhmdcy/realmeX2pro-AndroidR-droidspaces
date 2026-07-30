# Panic 日志持久化方案研究

> Realme X2 Pro (SM8150, kernel 4.14.190-perf+)
> 核心问题：bootloader (XBL) 在每次启动时清零 DDR，ramoops/pstore 全部无效

---

## 结论

| 方案 | 状态 | 说明 |
|------|------|------|
| ramoops | ❌ | XBL 清 DDR，warm reset 也无效 |
| pstore/blk backport | ❌ | `pstore_register()` 成功 → 立即 bootloop（14轮二分确认） |
| **panic_logstore** | **✅ 可用** | 真 panic 后日志完整存活到 `/cache/last_panic.txt` |

---

## 最终方案：panic_logstore

从 OnePlus SM8550 (commit `d92a4ce`) 移植，适配 4.14。

### 原理

```
panic() → 开中断 → do_logstore()
  → filp_open("/cache/last_panic.txt")
  → kmsg_dump_rewind / kmsg_dump_get_line (遍历环形缓冲)
  → kernel_write (写入文件)
  → vfs_fsync (刷到磁盘)
  → 关中断 → 继续 panic 路径 → emergency_restart()
```

### 文件改动（4 个，+119 行）

| 文件 | 说明 |
|------|------|
| `include/linux/panic_logstore.h` | 声明 `do_logstore()` |
| `kernel/panic_logstore.c` | 核心实现 ~85 行 |
| `kernel/panic.c` | panic() 中插入调用 |
| `kernel/Makefile` | 添加编译目标 + SELinux 头文件路径 |

### 4.14 适配改动

- `kmsg_dump_get_line` 使用 `struct kmsg_dumper`（4.x API）而非 `struct kmsg_dump_iter`（6.x API）
- 手动设置 `dumper->active = true`（正常应通过 `kmsg_dump_register()` 设置，但我们不注册）
- 写入路径改为 `/cache/last_panic.txt`（Realme 上没有 OnePlus 的 `/mnt/oplus/op2/`）
- 添加 `put_cred()` 清理（原代码有 leak）

### 验证结果

**手动触发**：`echo 1 > /sys/module/panic_logstore/parameters/trigger`
- 成功写入 7892 行内核日志到 `/cache/last_panic.txt`
- dmesg: `panic_logstore: Panic logstore is done.`

**真 panic**：`echo c > /proc/sysrq-trigger` → 重启 → TWRP 读取
- 成功写入 7950 行日志，panic 信息完整：
  ```
  Kernel panic - not syncing: sysrq triggered crash
  CPU: 4 PID: 10959 Comm: sh
  Call trace: dump_backtrace ... panic ... sysrq_handle_term ...
  ```
- 文件跨重启完整保留

### 触发方式

| 方式 | 命令 |
|------|------|
| 手动（安全） | `echo 1 > /sys/module/panic_logstore/parameters/trigger` |
| 自动（真 panic） | `echo c > /proc/sysrq-trigger` 或其他 panic 触发 |
| 恢复日志 | `cat /cache/last_panic.txt`（系统或 TWRP） |

### 局限性

- `kernel_write` + `vfs_fsync` 在 panic 上下文工作，作者自称 "not stable"
- 只能捕获写那一刻之前的日志（`smp_send_stop()` 之后的无法写入）
- 需要 `/cache` 分区已挂载（开机自动挂载）

### 读取日志

```bash
# 正常启动后
adb shell "su -c 'cat /cache/last_panic.txt'"

# TWRP 中
adb shell
TWRP $ cat /cache/last_panic.txt

# 复制到电脑
adb exec-out "su -c 'cat /cache/last_panic.txt'" > panic_log.txt
```

### 测试流程

```bash
# 确认模块加载
adb shell "su -c 'cat /sys/module/panic_logstore/parameters/trigger'"

# 手动触发（安全）
adb shell "su -c 'echo 1 > /sys/module/panic_logstore/parameters/trigger'"
adb shell "su -c 'cat /cache/last_panic.txt'"

# 真 panic 测试
adb shell "su -c 'echo c > /proc/sysrq-trigger'"
# 重启后读取 /cache/last_panic.txt
```

---

## 失败的方案：pstore/blk 完整 backport

### 做了什么

从 **Motorola MSM-4.14** (`05Alston/android_kernel_motorola_msm-4.14`) backport：

| 文件 | 行数 |
|------|------|
| `fs/pstore/zone.c` | ~1500 |
| `fs/pstore/blk.c` | ~800 |
| `include/linux/pstore_zone.h` | ~60 |
| `include/linux/pstore_blk.h` | ~50 |
| `fs/pstore/Kconfig`/`Makefile` 修改 | ~20 |
| 基础设施改动（`pstore.h`, `platform.c`, `kmsg_dump.h`等） | ~100 |

加上 OPLUS 冲突修复、`inode_trylock` 绕过。

### 14 轮二分实验结果

| # | ramoops | pstore/blk | CMDLINE | 结果 | 分析 |
|---|---------|------------|---------|------|------|
| #1 | 活动 | 不启用 | 无 | ✅ 启动 | 基准，纯 infra 改动 |
| #2 | 活动 | 注册（-EBUSY） | 无 | ✅ 启动 | ramoops 先占位，pstore_blk 拿不到 |
| #3 | 跳过 | 注册成功 | 无 | ❌ bootloop | 第一个失败 |
| #4 | 跳过 | 注册成功，console=64 | `ignore_loglevel` | ❌ bootloop | 怀疑 console flag 导致 |
| #5 | 跳过 | 注册成功，console=0 | `ignore_loglevel` | ❌ bootloop | 非 console 问题 |
| #6 | **活动** | **注册（-EBUSY）** | `ignore_loglevel` | **✅ 启动** | **关键：ramoops 占着位置就没事** |
| #7 | 跳过 | 注册成功，空 blkdev | `ignore_loglevel` | ❌ bootloop | 不是分区问题 |
| #8 | 跳过 | 注册成功，pmsg=64 | `ignore_loglevel` | ❌ bootloop | 不是 console 问题 |
| #9 | 跳过 | 注册成功，all flags=0 | `ignore_loglevel` | ❌ bootloop | flag 无关 |
| #10 | 跳过 | 注册成功，best_effort=true | `ignore_loglevel` | ❌ bootloop | best_effort 无关 |
| #11 | 跳过 | 注册成功，空 blkdev | 无 | ✅ 启动 | empty blkdev → zone 分配失败？ |
| #12 | 跳过 | 注册成功，pmsg=64 only | `ignore_loglevel` | ❌ bootloop | 不是 kmsg/console 特有 |
| #13 | `PSTORE_BLK=n` | 不编译 | `ignore_loglevel` | ✅ 启动 | 全部 infra 改动安全 |
| #14 | 活动 | 不启用 | `reboot=panic_warm` | ✅ 启动 | 纯 ramoops 测试（最终证实 DDR 清） |

### 失败原因分析

**直接原因：`pstore_register()` 成功 → bootloop。**

所有基础设施改动（Kconfig、头文件、`pstore.h` 的 `PSTORE_TYPE_BLK` 枚举定义等）都是安全的。block device 打开、zone 分配也是安全的。问题仅在 pstore_blk **成为活动后端**时出现。

**根本原因：OPLUS dump device 代码硬编码了 `psinfo->data` 类型。**

`drivers/soc/oplus/system/dump_device_info/dump_device_info.c` 中有：

```c
// OPLUS 代码假设 psinfo 的后端是 ramoops
struct ramoops_context *cxt = psinfo->data;
// ... 直接操作 cxt 的字段
```

当 ramoops 不注册、pstore_blk 注册成功时：
- `psinfo->data` 指向 `struct pstore_blk_context`（或 zone 结构），而非 `struct ramoops_context`
- OPLUS 代码按 ramoops 布局解析 → 内存越界 → 内核崩溃 → 重启循环

这就是为什么 `#6`（ramoops 活动，pstore_blk 拿 `-EBUSY`）能启动——`psinfo` 仍指向 ramoops。

```
ramoops 注册成功 → psinfo->data = ramoops_context ✓
pstore_blk 注册 → -EBUSY (已被占用) → psinfo 不变 ✓        → 启动

ramoops 跳过 → psinfo = 空
pstore_blk 注册成功 → psinfo->data = blk_context
OPLUS 按 ramoops_context 读 blk_context → 崩溃              → bootloop
```

### 为什么 panic_logstore 没有这个问题

panic_logstore：
- **完全不碰 pstore 框架** — 不调 `pstore_register()`、不改 `psinfo`
- OPLUS dump device 继续正常工作（`psinfo` 不受影响，或保持 NULL）
- 日常静默，只在 panic 时调用 `do_logstore()`
- 不创建 `/dev/pmsg0`、不注册 kmsg dumper、不参与任何系统路径
- 代码量 85 行，审计简单

---

## 关键教训

1. **不要和现有框架打架** — OPLUS/Realme 的 pstore 定制代码假设只有 ramoops 后端。引入第二个后端要改所有硬编码引用点。
2. **二分法是 panic 调试利器** — 14 轮构建排除了基础设施问题，精确定位到 `pstore_register()` 成功路径。
3. **最简单的方案最可靠** — 85 行的 panic_logstore 比 2500 行的 pstore/blk backport 更稳定。
4. **移植注意 4.14 的 API 差异** — `struct kmsg_dumper` vs `struct kmsg_dump_iter`，`dumper->active` 必须手动设置。

---

## 附：相关文件

| 文件 | 说明 |
|------|------|
| `source/kernel/panic_logstore.c` | panic_logstore 核心 |
| `source/include/linux/panic_logstore.h` | 头文件 |
| `README.md` | 分支概览和用法 |
