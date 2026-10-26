# 沉浸光感导航设计复查（2026-10-17）

## 实际阅读的官方规范

- [沉浸光感](https://developer.huawei.com/consumer/cn/doc/design-guides/immersivelight-0000002612101053)：顶部推荐 ULTRA_THIN；底部推荐 THIN 并结合与页面背景一致的渐变颜色蒙层。
- [底部页签](https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/bottomtab-0000001956787789)：悬浮栏高 56vp；三个页签在窗口小于 600vp 时宽 248vp，较宽窗口为 272vp；选中态明确、未选中态弱化；重复点击当前页签回到顶部；内容区不横滑切换页签。
- [标题栏](https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/titlebar-0000001929628982)：标准单行高度 56vp，标题和右侧操作区共同布局；一级页面隐藏返回按钮，二级页面提供返回路径。
- [手机](https://developer.huawei.com/consumer/cn/doc/design-guides/phone-0000001776694632)：优先系统控件，保证显示、热区与系统特性兼容。

## 发现与修正

| 实际问题 | 修正 |
| --- | --- |
| 自定义标题使用全宽 Row，标题贴边且将原生设置菜单挤出 | 新版使用标准字符串标题，由 Navigation 分配标题与菜单空间；楼栋选择移入内容控制区 |
| 深色悬浮栏的页签文字为黑色 | 新版显式使用系统强调色与次级文字色，保持图标与文字状态一致 |
| 底栏使用旧高度并随应用缩放，材质未指定层级 | 新版固定 56vp，使用 THIN 材质；明确三页签断点宽度 |
| 底部过渡与页面背景未明确匹配 | maskColor 使用页面背景资源，maskHeight 为 80vp（56 高度 + 8 底距 + 16 过渡） |
| 底部留白跟随应用字号缩放，不能对应固定悬浮栏 | 三页签滚动内容底部留白统一为 80vp |
| 重复点击当前页签没有回到顶部 | 三个页面绑定独立 Scroller，重复点击当前页签滚动至顶部 |

以上调整均限于 API 26 及以上；旧版标题 Row、底栏高度、内容留白和原有标签默认样式保留。未改变账单或备份数据。

## 验证范围

- DevEco SDK 26 构建成功，未签名 HAP 已覆盖安装并启动于两台 API 26 虚拟机。
- `10001` 手机浅色：截图确认标题左右留白、设置按钮及页签文字可见。
- `10003` 深色：检查概览、录入、房间三个页签；设置按钮成功打开更多设置，进入外观设置后可逐级返回。
- 概览滚动至底部后，历史账单按钮完全位于悬浮栏上方。房间页滚动与重复点击回顶另有界面树记录。
- 截图及 UITest 界面树位于 `outputs/harmonyos-qa/immersive-*`（忽略目录，不入库）。

尚未完成：API 12–25 设备视觉回归、系统大字号和界面缩放上限、软键盘与悬浮栏、真机材质表现及系统特效强度/关闭状态。两台 API 26 虚拟机的检查不能替代这些验收，也不代表全应用设计规范审查已完成。


## 2026-10-17 顶部空间渐变模糊

按[官方动态模糊指南](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/ui-design-navigation-dynamic-blur)接入 UI Design Kit 的 HdsNavigation / HdsNavDestination。API 26 及以上统一使用 `ScrollEffectType.GRADIENT_BLUR`，关闭随滚动距离改变强度的过渡，直接由系统提供顶部向下逐渐清晰的空间模糊。启用标题栏组件安全区，滚动容器关闭裁剪并绑定独立 Scroller，让内容经过标题栏时自然渐隐。标题、返回和设置按钮颜色使用系统语义色，按钮与材质由 HDS 绘制。旧系统保留 ArkUI Navigation / NavDestination 分支。

覆盖首页、更多设置、外观、关于、收据模板、备份恢复、PDF 留档、收据预览、楼栋编辑、房间编辑、历史账单和账单详情。编译通过。在 HarmonyOS 7 / API 26 的 Pura X Max 展开态模拟器覆盖安装后，检查首页、更多设置、外观设置、多级返回及收据模板长表单滚动；截图确认内容穿透标题栏并呈现空间渐变模糊。未实际运行 API 12–25 设备。

证据：`outputs/harmonyos-qa/gradient-home.png`、`gradient-more.png`、`gradient-settings.png`、`gradient-template-scrolled.png`。
