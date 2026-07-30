# Realme X2 Pro (RMX1931) 9008 EDL 救砖文档

> 适用于骁龙 855+ (SM8150) 平台，Realme X2 Pro / RMX1931 / CPH2095 / CPH22127

---

## 概述

Realme X2 Pro 使用高通 SM8150 平台。当系统完全无法启动（黑砖、死循环重启、fastboot/recovery 均无法进入）时，唯一的下级通道是 **EDL (Emergency Download) 模式**，即高通 9008 模式。

**注意**：不同年份的 X2 Pro 和 ColorOS/RealmeUI 版本进入 9008 的方式不同。根据 Coolapk Auting 的测试，Oplus 设备存在**两套引导机制**：
- **Recovery → 9008**：在 TWRP 中重启到 9008，不需要授权 firehose
- **三键硬进 9008**：需要高通授权签名 firehose（通常不可用）

---

## 信息源清单

### 泄露的免授权工具

| 工具 | 来源 | 说明 |
|------|------|------|
| **OplusEdlTool v2/v3** | github.com/salokrwhite/OplusEdlTool | 开源跨平台，支持云加载 firehose，v3 闭源但功能更强 |
| **OplusEdlTool (Kcaii fork)** | github.com/Kcaii/OplusEdlTool | 热门 fork |
| **OP Flash Tool** | github.com/stanley-fork/OP_Flash_Tool | 批处理脚本方案 |
| **bkerler/edl** | github.com/bkerler/edl | 通用高通 Firehose/Sahara 工具集 |
| **MSM Download Tool No Auth** | romprovider.com/download-realme-x2-pro-unbrick-tool-msm-download-tool-no-auth | Patched 版跳过授权检查 |
| **QFIL + QFIL Helper** | XDA Forum + 官方 QPST 包 | 高通官方救砖工具，配合 firehose 使用 |

### RMX1931 Firehose Loader 下载

| 来源 | 文件名 | 大小 | 备注 |
|------|--------|------|------|
| bypassfrpfiles.com | prog_firehose_ddr_fwupdate.mbn | ~30MB (zip) | 标称 No Auth |
| filewale.com/files/.../20945 | Realme_X2_Pro_Loader_Firehose_[elf] | ~251KB | 2024上传，2026更新 |
| filewale.com/files/.../18986 | Realme_X2_Pro_RMX1931_UFS_LODER_SM8150 | ~277KB | UFS 专用 |
| firmwaredrive.com | Realme X2 Pro Firehose files | - | 多种可用 |

### ROM / 底层字库

| 来源 | 内容 | 说明 |
|------|------|------|
| **azrom.net** | XML RMX1931EX-11-C.36-210310 QFIL 刷机包 | 5.1GB，完整 QFIL 包 |
| **XDA** RMX1931 Full flash thread | 完整分区 dump 方法 | 约 50GB 全分区备份 |
| **机享资源** (酷安) | X2 Pro 底层字库 | 救砖用底层分区文件 |

### 社区讨论

| 平台 | 帖子/链接 | 内容 |
|------|-----------|------|
| **XDA** | (Guide) How to Flash hard bricked Realme X2 Pro | ROM2Box + OFP 刷机教程 |
| **XDA** | Realme X2 Pro RMX1931(ex) Full flash | QFIL Helper 完整备份教程 |
| **XDA** | [RMX1931] - TWRP with QFIL | 用 QFIL 刷写 recovery |
| **Coolapk** | Auting - RealmeX 强解BL | 两套 9008 引导机制分析 |
| **Coolapk** | 我叫小特 - X2 Pro 远程 9008 救砖 | 提供收费远程救砖服务 |
| **Coolapk** | nfxky6783 - 刷机工具汇总 | 工具列表 |

---

## 实操方案：OplusEdlTool (推荐)

### 下载

```bash
git clone https://github.com/salokrwhite/OplusEdlTool.git
```

或从 Release 下载预编译二进制：
https://github.com/salokrwhite/OplusEdlTool/releases

### 准备工作

1. 安装高通驱动 (QDLoader HS-USB Driver)
2. 下载 RMX1931 的 firehose loader (prog_firehose_ddr_fwupdate.mbn)
3. 下载对应版本的官方固件 (OFP 格式)
4. 如果只需要备份/恢复分区，准备 50GB+ 空余磁盘空间

### 进入 9008 模式

**方法 A：从 TWRP 进 9008 (推荐，不需要授权 firehose)**
```
手机进入 TWRP → 高级 → 进入 9008 模式
电脑设备管理器应看到 "Qualcomm HS-USB QDLoader 9008"
```

**方法 B：三键强进 (可能需要授权 firehose)**
```
关机 → 同时按住 音量上 + 音量下 → 插入 USB 线
看到 9008 端口后松开
```

### 刷机流程

1. 运行 OplusEdlTool.exe (管理员权限)
2. **Enter Firehose Mode** → 载入 `prog_firehose_ddr_fwupdate.mbn`
3. 设备被识别后显示分区表
4. **Flash ROM** → 选择解压后的 OFP 固件目录
5. 载入 `rawprogram0.xml` 和 `patch0.xml`
6. 点击 **Start Flash**（约 10 分钟）

**注意**：不要在 "备份/恢复" 中勾选 `persist` 分区，误操作会导致传感器永久损坏。

### 只看日志不救砖的情况

如果想在把手机彻底搞死之前，尝试在 9008 下读取 RAM：
1. OplusEdlTool → **Read Partitions**
2. 选择 `boot` 或 `vendor_boot` 等小分区测试读取
3. 理论上可以 dump 0xB7E00000 开始的 4MB ramoops 区域

但每次 crash → 进 9008 → dump → 解析 至少 10-15 分钟。不如 pstore/blk 直接写 eMMC 分区方便。

---

## 实操方案：QFIL + 泄露 Firehose (备选)

1. 下载安装 QPST (Qualcomm Product Support Tool)
2. 打开 QFIL (Qualcomm Flash Image Loader)
3. Config → 选择 Flat Build
4. Load XML → 选择 `rawprogram0.xml` / `patch0.xml`（来自官方固件或分区备份）
5. Programmer Path → 选择 `prog_firehose_ddr_fwupdate.mbn`
6. 手机进 9008 → 点击 **Download**

### QFIL Helper 全分区备份

对于还没有变砖、想提前备份的场景：

1. QFIL 配置好 firehose 连接设备
2. Tools → Partition Manager → 保存分区表快照
3. 运行 QFIL Helper，设定 COM 端口
4. 逐分区读取并保存为 `.bin`
5. 关键分区：`cdt`, `sbl`, `xbl`, `abl`, `boot`, `vendor_boot`, `dtbo`, `vbmeta`

---

## 警告

1. **9008 刷机有变砖风险**，操作不当可能导致硬件损坏（如写坏 CDT、PERSIST 分区）
2. 泄露的 firehose loader 来源不明，有安全隐患，建议在**离线/虚拟机**环境使用
3. 刷全分区固件会**丢失 IMEI** 如果没提前备份 EFS/QCN
4. 对于 X2 Pro 这种较老机型 (2019)，ColorOS 11/RealmeUI 2.0 的 9008 通道仍然开放，但**切勿升级到可能熔断 9008 的新系统**
5. 如果手机还能进 fastboot/recovery，优先用 fastboot 刷机，不要轻易尝试 9008

---

## 什么时候需要 9008 救砖

| 症状 | 方案 |
|------|------|
| 卡第一屏，但能进 fastboot | fastboot 刷 boot/recovery/vbmeta |
| 卡第一屏，能进 TWRP | TWRP 刷入修复包 |
| 黑砖，按住音量键有反应 | 尝试进 9008 → OplusEdlTool |
| 完全没反应（深度放电） | 充电 30 分钟再试 |
| EDL 都无法识别 | 可能需要拆机短接进入 9008 |
