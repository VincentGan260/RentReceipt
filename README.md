# 租簿 RentReceipt

> **⚠️ Android 用户请弃用 v1.0，并升级至 [最新版本](https://github.com/VincentGan260/RentReceipt/releases/latest)。** v1.0 与后续版本签名不同，无法直接覆盖安装。请先在旧版导出 ZIP 备份，再卸载 v1.0、安装新版并恢复备份；未备份前请勿卸载或清除数据。

给出租屋房东用的记账 App：管理楼栋与房间、每月抄水电表、自动算房租水电账单、生成房租单图片/PDF、导出留档与备份。所有数据只存在你自己手机上，不联网、不上传。

Android（Kotlin / Jetpack Compose）与 iOS（Swift / SwiftUI）两套实现，共用同一套数据模型和备份格式。

原生 HarmonyOS（ArkTS / ArkUI）客户端正在适配，已补齐主要业务、备份及导出入口。构建方式见 [鸿蒙工程说明](harmonyos/README.md)，已测与待测功能见 [对齐清单](docs/harmonyos-feature-parity.md)。

---

## 功能一览

| 功能 | 说明 |
| --- | --- |
| 多楼栋管理 | 每栋楼独立的水电单价、可选公共服务费单价、表具上限；可随时新增、改名、切换 |
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

环境要求：JDK 21、Android SDK（compileSdk 37 / minSdk 31）。

```bash
# 1. 告诉 Gradle 你的 SDK 在哪
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties

# 2. 编译调试包
./gradlew assembleDebug

# 3. 装到手机 / 跑单元测试
./gradlew installDebug
./gradlew test
```

发布包（开启 R8 裁剪 + 资源压缩）：

```bash
./gradlew assembleRelease   # 产物：app/build/outputs/apk/release/app-release.apk
```

#### 发布签名（正式发布必读）

`release` 构建从项目根目录的 `keystore.properties` 读取签名配置：

```properties
storeFile=/绝对路径/rentreceipt.jks
storePassword=密钥库密码
keyAlias=rentreceipt
keyPassword=密钥密码
```

正式构建缺少密钥文件或必要配置时会直接失败，不会回退到 debug 签名。调试构建不需要正式密钥。

生成自己的密钥（有效期 30 年）：

```bash
keytool -genkeypair -v -keystore rentreceipt.jks -keyalg RSA -keysize 2048 \
  -validity 10950 -alias rentreceipt \
  -dname "CN=你的名字, OU=部门, O=组织, C=CN"
```

验证签名是否生效：

```bash
apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk
# 应看到你自己的 CN，而不是 CN=Android Debug
```

发布版本启用 v3 签名，但这并不自动建立密钥轮换关系。轮换需要旧密钥及有效的轮换证明，不能用来恢复已经丢失的密钥。

> GitHub 直接分发的 APK 必须一直使用同一签名密钥，或事先建立有效轮换关系。丢失密钥且没有轮换关系时，旧版无法覆盖升级；卸载前先导出 ZIP 备份。使用 Play App Signing 的应用需按 Google Play 的密钥恢复流程处理。
>
> `keystore.properties` 含明文密码，`*.jks` 是密钥本体，两者**都已在 `.gitignore` 中**，切勿提交。

`local.properties` 与 `keystore.properties` 都含本机路径或密码，均不会入库。

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

公共服务费单价可留空，留空不收取；填写后按用电度数 × 公共服务费单价计算，金额四舍五入到元并计入合计。收据的单价列仅显示水、电单价，房租与公共服务费仅显示金额。

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

备份 ZIP 采用 `format = rent-receipt`、Android 与 iOS 当前 `version = 10`，内含以下 CSV：

| 文件 | 内容 |
| --- | --- |
| `manifest.csv` | 格式标识与版本号 |
| `buildings.csv` | 楼栋及默认水电单价、可选公共服务费单价、表具上限 |
| `rooms.csv` | 房间、月租、自定义单价、押金状态 |
| `bills.csv` | 历史账单（读数、用量、各项金额、是否已收） |
| `receipt_templates.csv` | 房租单排版模板（元素内容、坐标、字号、对齐、颜色） |
| `bill_charges.csv` | 账单其他收费项 |
| `room_charges.csv` | 房间每月固定费用（版本 10） |

Android 与 iOS 均支持房间自定义公共服务费及每月固定费用，共用版本 10 备份格式并兼容版本 1–9。恢复旧备份时，缺少的新设置使用默认值，并保留历史账单金额。

iOS 升级时，旧本地 JSON 缺少公共服务费字段会使用默认值，不会因此丢失原有账单。

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
- Android 端数据未做云同步，换机请走 ZIP 备份

---

## 更新日志

### v1.3（2026-10-26）

- Android：房间搜索改为底部展开、实时筛选，支持清除和退出；优化玻璃底栏选中动画。
- iOS：新增独立搜索页签，支持概览、录入和房间页面的房号筛选，并适配 iOS 26 搜索交互。
- Android / iOS：加强金额、单价和表具上限校验；删除房间及恢复备份时清理旧草稿；修复电表上限留空后的恢复行为。
- iOS：重复批量标记已收时保留原收款日期，调整押金状态变更日期记录，加强出账月份和数字格式校验。
- Android / iOS：调整未配置公共服务费时的收据单价展示。
- 新增原生 HarmonyOS 源码：本地账本、出账收租、ZIP v10 备份恢复、收据分享与批量导出、档案 PDF、模板和外观设置；设备兼容性与完整验收仍在推进。
- 本次提供 Android 正式签名 APK 及三平台源码，不提供 iOS / HarmonyOS 安装包。备份继续使用 v10 格式，兼容 v1–v9；升级前建议导出 ZIP 备份。

### v1.2（2026-10-12）

- 新增公共服务费：按用电量计算，支持楼栋默认单价与房间独立单价（Android / iOS）。
- 新增房间每月固定收费，出账时自动带入（Android / iOS）。
- 房租单增加水电单价与公共服务费展示，优化排版。
- 备份格式升级至 v10，兼容 v1–v9 旧备份并保留历史账单金额。
- Android 更新柔光玻璃界面、悬浮搜索与字体布局，新增关于及开源许可说明。

### v1.1（2026-10-03）

**新功能**
- 支持删除楼栋（Android / iOS 双端）：级联清除该楼栋的房间、历史账单与未提交草稿，删除前二次确认并提示影响范围
- 所有楼栋删除后展示引导页，可从空状态直接新增楼栋

**改进**
- 房租单"房间号"栏改为渲染完整一行「X号（楼栋名）」，楼栋名大字号蓝色衬线体，超宽自动等比缩放
- Android 底部导航栏样式改为五选一：液态玻璃（官方示例，Android 13+ 默认）/ 固定·图标和文字 / 固定·仅图标 / 固定·仅选中项文字 / 悬浮·仅图标
- 页面导航迁移至 miuix-nav 体系，支持预测性返回手势与转场动画

**构建**
- Java 17 → 21；miuix 0.9.3 → 0.9.4（新增 miuix-nav 依赖）
- 正式签名增加 storeFile 存在性校验，密钥缺失时不再误用失效配置

**修复**
- 数据为空（buildings 为空列表）时的空指针崩溃隐患

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

## 签名密钥备份与换电脑

1. 备份当前已发布 APK 对应的原始 `.jks` 文件，不要为换电脑重新生成密钥。
2. 在密码管理器中保存 `storePassword`、`keyAlias` 和 `keyPassword`。
3. 将密钥保存在两处独立位置，例如加密云盘和离线 U 盘，并确认备份可读。
4. 换电脑后恢复密钥，在根目录重新创建 `keystore.properties`，更新 `storeFile` 路径。
5. 从当前可信的正式 APK 获取证书指纹：

```bash
apksigner verify --print-certs 当前正式版本.apk
```

将输出中的 `certificate SHA-256 digest` 保存为仓库的 Actions Secret `SIGNING_CERT_SHA256`。仓库 Settings → Secrets and variables → Actions 中还需配置 `KEYSTORE_BASE64`、`KEYSTORE_PASSWORD`、`KEY_ALIAS` 和 `KEY_PASSWORD`。发布流程会核对指纹，任何密钥变更都会阻止发布，需人工确认原因。

GitHub Secrets 不能直接读取取回原值，不可作为唯一备份。密钥和密码不要提交到仓库，也不要发到聊天中。

### Android 柔光玻璃组件来源

复用 HyperModifier 的 GPL-3.0 控件，来源版本、修改记录和分发要求见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。发布 APK 时需同时提供该版本完整对应源码及构建脚本。
