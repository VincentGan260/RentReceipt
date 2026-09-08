# 租簿 RentReceipt

给出租屋房东用的记账 App：管理楼栋与房间、每月抄水电表、自动算房租水电账单、生成房租单图片/PDF、导出留档与备份。所有数据只存在你自己手机上，不联网、不上传。

Android（Kotlin / Jetpack Compose）与 iOS（Swift / SwiftUI）两套实现，共用同一套数据模型和备份格式。

---

## 功能一览

| 功能 | 说明 |
| --- | --- |
| 多楼栋管理 | 每栋楼独立的水电单价、表具上限；可随时新增、改名、切换 |
| 房间管理 | 房号、月租、押金（未收/已收/已退）、出租状态；房间可单独覆盖单价 |
| 抄表出账 | 录入上月/本月水表电表读数，自动算用量与金额；**草稿自动保存**，退出不丢 |
| 表具归零/换表 | 本期读数小于上期时，自动按表具上限折算；若是换表可手动填实际用量 |
| 漏月补记 | 中间月份漏抄时，会提示是否把漏掉月份的房租合并到本期 |
| 自定义收费项 | 每单可加任意条目的额外收费（网费、卫生费等） |
| 收租登记 | 逐间标记已收/未收，或一键标记当月全部已收；自动统计当月已收总额 |
| 房租单 | 生成竖版房租单图片，可保存到相册或直接分享给租客 |
| 历史查询 | 按房间查看逐月账单，展示水表/电表读数的 `上月 → 本月` 与用量 |
| 房东留档 | 按楼栋 + 月份区间导出 PDF（每房间一行，各月份列出水电用量） |
| 完整备份 | 导出 ZIP（含全部楼栋、房间、历史账单的 CSV），可导入恢复 |
| 界面设置 | 主题、动画、页面缩放等外观选项 |

---

## 快速开始（编译运行）

### Android

环境要求：JDK 17、Android SDK（compileSdk 37 / minSdk 31）。

```bash
# 1. 告诉 Gradle 你的 SDK 在哪
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties

# 2. 编译调试包
./gradlew assembleDebug

# 3. 装到手机 / 跑单元测试
./gradlew installDebug
./gradlew test
```

发布包（开启 R8 裁剪 + 资源压缩，体积从 70 MB 降到约 4 MB）：

```bash
./gradlew assembleRelease   # 产物：app/build/outputs/apk/release/app-release.apk
```

> 当前 `release` 构建类型暂用 **debug 密钥**签名（`app/build.gradle.kts` 中的 `signingConfig = signingConfigs.getByName("debug")`），保证产物拿去就能装。
> 若要正式发布，请生成自己的 keystore，并在 `build.gradle.kts` 里换成正式 `signingConfigs`。
> 注意：签名密钥一旦更换，已安装的用户需要先卸载才能升级，**升级前务必先导出 ZIP 备份**。

`local.properties` 含本机路径，已在 `.gitignore` 中，不会被提交。

### iOS

```bash
open ios/RentReceipt/RentReceipt.xcodeproj
```

Xcode 中选择目标设备后直接 Run 即可。

---

## 使用指南

App 底部有三个 Tab：**概览**、**录入**、**房间**。

### 1. 建立房间

进入 **房间** 页 → 点右上角 **新增**：

- **房号**：支持「101」「铺1」「A座302」等任意文字，排序按数字优先智能处理
- **月租**：该房间的月租金
- **已出租**：开关，影响概览页的统计
- **押金**：金额 + 状态（未收 / 已收 / 已退），切换状态会自动记录当天日期
- 房间内还可单独打开「自定义水价 / 电价 / 水表上限 / 电表上限」，不打开就跟随楼栋默认设置

> 若你有多栋楼：在 **房间** 页顶部可 **新增楼栋** 或 **楼栋改名**，各栋数据相互独立。

### 2. 设置水电单价

**房间** 页 → **默认单价** → **修改**：

- 水费（元/吨）、电费（元/度）
- **表具归零上限**：水表/电表的最大读数。电表走满归零（例如 10000）时，填了上限才能算出正确用量；留空表示不做处理

### 3. 每月抄表

进入 **录入** 页：

1. 顶部左右箭头选择**抄表月份**。房租单月份 = 抄表月的**下个月**，日期固定为当月 1 号，可随时切到历史月份补录
2. 顶部搜索框可按房号快速定位房间
3. 每个房间填 4 个数：**上月水表 / 本月水表 / 上月电表 / 本月电表**
   - 首次录入时，上期读数会尝试从上月账单自动带出
   - 输入过程**自动存草稿**，退出重进不会丢
4. 需要额外收费时，点 **其他收费项** → **添加**，填写名称与金额
5. 填完即生成该月房租单

**两个会自动处理的情况：**

- **读数变小**：如果本期读数小于上期，会提示「按归零上限计算」还是「换表填实际用量」。换表时直接在「换表实际用量」里填数即可
- **中间月份漏抄**：如果检测到有月份没出过单，会询问是否把那些月份的**房租合并**到本期（水电仍按两次实际抄表读数的差值计算）

### 4. 收租登记

**概览** 页：

- 左右箭头切换月份，查看当月各房间是否已收
- 点房间卡片上的 **标记已收** 逐间登记；也可点 **一键标记本月全部已收**
- 顶部卡片显示当月**已收总额**，并分别列出已收水费、电费
- 点房间卡片可进入该房间的**历史账单**，查看逐月读数与用量

### 5. 房租单（给租客）

两种方式：

- **单个**：房间历史 → 点某月账单 → 预览房租单 → **保存高清图片**（存入相册）或 **分享图片**
- **批量**：**录入** 页顶部的 **导出 N 张收据**，一次性把当月所有收据导出到相册

### 6. 房东留档 PDF

**房间** 页 → **房东留档 PDF** → 选开始/结束月份 → **导出 PDF**

导出的是一张横向汇总表：**每行一个房间，每列一个月份**，格子里是当月的水、电用量。文件保存在手机的 `文档/房租留档/<楼栋名>/` 目录下。

### 7. 备份与恢复

**房间** 页 → **完整备份与恢复**：

- **导出 ZIP**：打包全部楼栋、房间、设置和历史账单（CSV 格式，见下方"数据结构"）
- **导入恢复**：选择之前导出的 ZIP，**会覆盖当前所有数据**，操作前建议先导出一份

> 换手机、清数据、卸载前，请务必先导出 ZIP。Android 端数据存在 App 私有的 `SharedPreferences` 里，清除应用数据即丢失。

---

## 数据结构与备份格式

备份 ZIP 采用 `format = rent-receipt`、当前 `version = 8`，内含以下 CSV：

| 文件 | 内容 |
| --- | --- |
| `manifest.csv` | 格式标识与版本号 |
| `buildings.csv` | 楼栋及默认单价、表具上限 |
| `rooms.csv` | 房间、月租、自定义单价、押金状态 |
| `bills.csv` | 历史账单（读数、用量、各项金额、是否已收） |
| `receipt_templates.csv` | 房租单排版模板（元素内容、坐标、字号、对齐、颜色） |

Android 与 iOS 使用同一份格式，可跨平台互相导入。

Android 端运行时数据保存在 `SharedPreferences`（`rent_receipt_data`），以 JSON 序列化。

---

## 项目结构

```
.
├── app/                                  # Android 主模块
│   └── src/main/java/com/vincent/rentreceipt
│       ├── model/Models.kt               # 数据模型 + BigDecimal 金额计算
│       ├── data/RentRepository.kt        # 仓储层（SharedPreferences 持久化）
│       ├── data/BackupArchive.kt         # ZIP 备份导入导出
│       ├── export/ReceiptExporter.kt     # 房租单图片渲染与导出
│       ├── export/ArchivePdfExporter.kt  # 房东留档 PDF
│       └── ui/                           # Compose 界面（概览 / 录入 / 房间）
├── ios/RentReceipt/RentReceipt/          # iOS SwiftUI 实现
│   ├── Models.swift / BillCalculator.swift
│   ├── AppStore.swift / BackupArchive.swift
│   ├── ReceiptRenderer.swift / ArchivePDFRenderer.swift
│   └── OverviewView.swift / EntryView.swift / RoomsView.swift
├── assets/branding/                      # 应用图标源文件
└── design/                               # 设计稿
```

## 技术栈

| 平台 | 技术 |
| --- | --- |
| Android | Kotlin、Jetpack Compose（Material 3 + [Miuix](https://github.com/miuix-kotlin-multiplatform/miuix)）、Coroutines / Flow、Java 17、AGP 9.2.1、minSdk 31 / targetSdk 37 |
| iOS | Swift、SwiftUI |

包名：`com.vincent.rentreceipt`　·　应用名：**租簿**

金额计算全程使用 `BigDecimal`，避免浮点误差；用量按「本期读数 − 上期读数」，支持表具归零与换表修正。

---

## 已知限制

- 房租单目前使用内置默认排版，模板编辑入口尚未开放（数据模型与备份格式已支持）
- `ui/HomeScreen.kt` 是早期拍照录入方案的遗留页面，当前未接入
- Android 端数据未做云同步，换机请走 ZIP 备份

---

## 贡献

欢迎 Issue 与 Pull Request。提交前请：

```bash
./gradlew test        # Android 单元测试
./gradlew lint        # 静态检查
```

代码风格遵循 Kotlin 官方约定，界面部分沿用 Miuix 设计语言。

---

## 许可证

本项目采用 **GNU General Public License v3.0 (GPL-3.0)** 授权，详见 [LICENSE](LICENSE)。

你可以自由使用、修改和分发本软件，但任何基于本项目的衍生作品**在分发时必须同样以 GPL-3.0 开源**，并保留原始版权声明。

Copyright (C) 2026 VincentGan260
