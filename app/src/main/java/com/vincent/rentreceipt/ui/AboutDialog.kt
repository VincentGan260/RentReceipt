package com.vincent.rentreceipt.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.vincent.rentreceipt.BuildConfig

private data class OpenSourceTechnology(val name: String, val version: String, val purpose: String, val license: String, val url: String)

private val technologies = listOf(
    OpenSourceTechnology("HyperModifier / Deadliner", "84fab7c", "复用柔光玻璃材质、悬浮导航、顶部控件、分组设置与预设配色；为房租功能进行了界面适配。", "GPL-3.0", "https://github.com/AritxOnly/HyperModifier"),
    OpenSourceTechnology("Miuix", "0.9.4", "界面控件、偏好设置、图标、导航、弹窗与模糊渲染。", "Apache-2.0", "https://github.com/compose-miuix-ui/miuix"),
    OpenSourceTechnology("Jetpack Compose / Material 3", "Compose BOM 2026.06.00 · Material 3 1.4.0", "声明式界面、布局、文字、输入交互、动画和 Material 主题基础。", "Apache-2.0", "https://developer.android.com/jetpack/compose"),
    OpenSourceTechnology("AndroidX", "Core 1.16.0 · Activity 1.12.4 · Lifecycle 2.10.0", "安卓兼容能力、Activity 集成、生命周期与 ViewModel。完整模块版本见依赖清单。", "Apache-2.0", "https://developer.android.com/jetpack/androidx"),
    OpenSourceTechnology("MaterialKolor", "4.1.1", "生成与映射固定浅色／深色主题的色彩方案。", "MIT", "https://github.com/jordond/materialkolor"),
    OpenSourceTechnology("Shapes", "1.2.0", "为玻璃导航与按钮提供平滑圆角及胶囊形状。", "Apache-2.0", "https://github.com/Kyant0/Shapes"),
    OpenSourceTechnology("AndroidLiquidGlass", "上游算法来源", "玻璃镜片与圆角距离场算法的参考来源；保留上游着色器中的署名说明，并非独立运行依赖。", "Apache-2.0", "https://github.com/Kyant0/AndroidLiquidGlass"),
    OpenSourceTechnology("Kotlin / Coroutines", "版本见完整依赖清单", "应用语言基础、异步任务与 Flow 数据流。", "Apache-2.0", "https://github.com/Kotlin/kotlinx.coroutines")
)

@Composable
fun AboutDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    var selected by remember { mutableStateOf<OpenSourceTechnology?>(null) }
    var document by remember { mutableStateOf<Pair<String, String>?>(null) }
    val inventory = remember { context.assets.open("licenses/RUNTIME-DEPENDENCIES.txt").bufferedReader().use { it.readText() } }
    fun open(url: String) { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    val technology = selected
    val currentDocument = document
    when {
        technology != null -> KitAlertDialog(
            title = technology.name, onDismissRequest = { selected = null },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(technology.version, style = KitTypography.titleMedium, color = KitColors.primary)
                    AboutDetail("用途", technology.purpose)
                    AboutDetail("开源许可", technology.license)
                    AboutDetail("项目来源", technology.url)
                    if (technology.name.startsWith("HyperModifier")) {
                        AboutDetail("复用说明", "原作者保留署名与版权。修改和导入文件记录在项目的 THIRD_PARTY_NOTICES.md 与源码清单中。")
                    }
                }
            },
            confirmButton = { TextButton("查看项目", onClick = { open(technology.url) }) },
            dismissButton = { TextButton("返回", onClick = { selected = null }) }
        )
        currentDocument != null -> KitAlertDialog(
            title = currentDocument.first, onDismissRequest = { document = null },
            text = { Text(currentDocument.second, style = KitTypography.summary) },
            confirmButton = { TextButton("返回", onClick = { document = null }) }
        )
        else -> KitAlertDialog(
            title = "关于房租单生成", onDismissRequest = onDismiss,
            text = {
                Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("房租单生成", style = KitTypography.titleLarge)
                    Text("版本 ${BuildConfig.VERSION_NAME} · Android", color = KitColors.onSurfaceVariant)
                    Text("用于楼栋、房间、房租与水电账单管理，以及收据生成、备份和导出。")
                    AboutDetail("项目许可", "GPL-3.0。允许按许可使用、修改与再分发，不提供担保。分发 APK 时须提供对应版本的完整源码和构建脚本。")
                    Text("开源技术与致谢", style = KitTypography.titleMedium)
                    Text("点击条目查看用途、版本、许可和原项目。", style = KitTypography.summary, color = KitColors.onSurfaceVariant)
                    technologies.forEach { technology ->
                        com.aritxonly.myhypermodifier.SettingItem(
                            headlineText = technology.name,
                            supportingText = technology.license + " · " + technology.version,
                            trailingContent = { Icon(KitIcons.Forward, null, tint = KitColors.onSurfaceVariant) },
                            onClick = { selected = technology }
                        )
                    }
                    TextButton("完整运行依赖清单", onClick = { document = "运行依赖与许可" to inventory })
                    TextButton("查看 GPL-3.0 全文", onClick = {
                        document = "GPL-3.0" to context.assets.open("licenses/HyperModifier-GPL-3.0.txt").bufferedReader().use { it.readText() }
                    })
                    TextButton("查看 Apache-2.0 全文", onClick = {
                        document = "Apache-2.0" to context.assets.open("licenses/Apache-2.0.txt").bufferedReader().use { it.readText() }
                    })
                }
            },
            confirmButton = { TextButton("关闭", onClick = onDismiss) },
            dismissButton = { TextButton("项目源码", onClick = { open("https://github.com/VincentGan260/RentReceipt") }) }
        )
    }
}

@Composable
private fun AboutDetail(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, style = KitTypography.summary, color = KitColors.onSurfaceVariant)
        Text(value, style = KitTypography.bodyLarge)
    }
}
