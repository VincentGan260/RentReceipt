# 租簿原生鸿蒙客户端

开发中：已完成数据模型、精确账单计算、本地存储，以及概览、录入、房间管理、楼栋/房间编辑、历史查询与收租操作。已新增 ZIP v10 备份恢复（兼容旧版）、高清收据预览/相册/分享/批量导出、楼栋模板编辑、档案 PDF、外观和关于页面；逐项设备验收及上架材料仍在推进。

最低兼容 HarmonyOS 5.0.0（API 12），本机使用 DevEco Studio 26.0.0 SDK 构建。手机/折叠屏同属 phone 设备类型。首页随窗口宽度调整卡片列数；录入表单最多两列，编辑与详情在宽屏使用原生双栏导航。

## 沉浸光感适配

按照华为官方[开启沉浸光感](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-enable)指导，在入口模块 `module.json5` 中声明 `ohos.arkui.UIMaterial.state=enable`，保持 targetSdkVersion 为 26.0.0、compatibleSdkVersion 为 5.0.0(12)。由支持该能力的新系统为系统弹窗、日期选择器、Select、Toggle 及符合条件的底部 TabBar 等组件应用沉浸光感。

API 26 及以上使用原生 Tabs.barFloatingStyle、barOverlap 和沉浸式系统材质，并将首页设置操作移入 Navigation 原生菜单按钮。三个页签的滚动内容增加底部留白，避免末项被悬浮栏遮挡。新增接口调用放在 sdkApiVersion >= 26 的运行时保护内；API 12–25 保留原有顶部 Row、设置按钮、底栏高度及内容留白。普通内容卡片保持现有样式。参考官方[沉浸光感典型场景](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sample)及[组件适配沉浸光感](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/arkts-immersive-light-sense-component-adaptation)。

设备验收待完成：在 API 26 的支持设备上重新安装构建产物，检查楼栋下拉菜单、月份选择弹窗、删除/覆盖确认弹窗、外观开关和底部标签栏，覆盖浅色/深色模式、文字对比度及系统关闭特效时的表现；在 API 12–25 上对照原界面检查相同入口。构建通过不代表已完成新旧系统视觉验收。

从仓库根目录执行：

```bash
bash tools/build-harmonyos.sh
```

脚本使用 DevEco 自带 Node、Java 和 Hvigor，在英文临时路径构建，规避 Hvigor 对中文路径的限制。产物复制到 entry/build/outputs。未配置签名时生成 unsigned HAP，不能用于市场提交。

如需在 DevEco IDE 中使用，建议将工程复制到英文路径后打开。AGC 上架记录仍待核对；本机调试签名保存在忽略文件 signing-config.local.json 中。需要签名时执行 `RENTRECEIPT_SIGN=1 bash tools/build-harmonyos.sh`，凭据仅在临时构建目录注入。勿提交密钥、密码或签名文件。

完整功能验收与上架准备见 ../docs/harmonyos-migration.md。

## 业务基础验证

```bash
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --test harmonyos/tests/*.test.cjs
```

从仓库根目录执行。测试直接转译并运行生产 `.ets` 源码；原生构建另行检查 ArkTS。iOS 对齐测试编译仓库中的 Swift 模型和计算器，需要已安装的 Xcode。测试涵盖十进制运算、计费边界、持久化失败、并发保存、数据损坏和删除行为。

本地持久化使用应用私有目录的 JSON 快照，包含业务数据与草稿。先写临时文件并同步，再重命名替换；写入失败不发布新的内存状态。文件存在但内容损坏时返回错误，禁止自动覆盖为空数据。这个本地快照格式独立于跨平台 ZIP v10，ZIP v10 与本地快照相互独立。导入前预览并确认全库覆盖，写入失败保留原数据。

主机文件适配测试不替代鸿蒙设备测试；未签名 HAP 已在 HarmonyOS 7 / API 26 手机与折叠屏模拟器安装验证，覆盖输入、出账、收租、重启恢复和折叠接续。HarmonyOS 5 与远程真机、较大字体和全部业务边界仍需继续验收。

UI 验证记录见 ../docs/harmonyos-ui-validation.md。测试截图与界面树保存在 outputs/harmonyos-qa（不入库）。官方 UITest 辅助脚本为 tools/harmonyos-ui.py；使用前必须获得用户对命令行 UI 控制的授权，且只用于前台租簿测试应用。

完整功能对齐矩阵见 ../docs/harmonyos-feature-parity.md，新增系统集成的已测/待测项以该表和 UI 验证记录为准。

档案 PDF 已增加可搜索、复制的 Unicode 文字层，保留原有图像版面；批量收据导出支持停止生成并清理本轮临时图片。完整自动测试当前为 51 项。
