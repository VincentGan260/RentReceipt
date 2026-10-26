# 项目协作说明

## 新会话的阅读方式

- 用户希望保存项目背景，减少每次新会话重复扫描整个文件夹。先阅读本文件和 `docs/project-context.md`，再按当前任务读取相关文档与源码。
- 不需要默认通读整个仓库；先用 `rg --files` 或定向搜索定位文件。不要为了解项目而读取构建缓存、全部产物或全部历史文档。
- 开始修改前查看 `git status --short`，保留已有未提交修改，不擅自回退或覆盖。
- 以实际源码和当前验证结果为准；项目摘要中的历史状态不能替代检查。
- 重要决定、跨会话约束或下一步发生变化时，简短更新 `docs/project-context.md`。不要把聊天全文、常规命令输出或敏感信息写入摘要。
- 与用户使用中文沟通。

## 项目入口

- `README.md`：产品功能、备份格式、Android/iOS 构建与项目结构。
- `app/`：Android，Kotlin / Jetpack Compose。
- `ios/RentReceipt/`：iOS，Swift / SwiftUI。
- `harmonyos/`：原生 HarmonyOS，ArkTS / ArkUI；先读 `harmonyos/README.md`。
- `docs/`：平台迁移、功能对齐与验收记录；按任务选择相关文件。
- `tools/`：鸿蒙构建及 UI 验证辅助脚本。

## 关键约束与验证

- 这是本地离线的出租屋记账应用；涉及账单计算、持久化和备份时，注意历史数据与跨平台兼容性。
- Android/iOS 文档记录的 ZIP 备份格式为 `rent-receipt` v10，兼容 v1–v9；修改前核对各平台实际实现。
- 不读取或记录与任务无关的签名凭据；不要提交 `keystore.properties`、`local.properties`、`*.jks` 或鸿蒙本地签名配置。
- Android 常用验证：`./gradlew test`、`./gradlew lint`；按改动选择必要检查。
- 鸿蒙构建：`bash tools/build-harmonyos.sh`；业务测试及环境要求见 `harmonyos/README.md`。
- 构建或主机测试通过不等于设备验收通过；明确报告实际执行的检查及未验证部分。
