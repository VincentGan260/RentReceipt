package com.vincent.rentreceipt.ui

import android.content.Context
import android.os.Build
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.theme.ThemeColorSpec
import top.yukonga.miuix.kmp.theme.ThemePaletteStyle
import top.yukonga.miuix.kmp.preference.OverlayDropdownPreference
import kotlin.math.roundToInt

enum class AppColorMode(val label: String) {
    SYSTEM("跟随系统"),
    LIGHT("浅色"),
    DARK("深色")
}

enum class BottomBarStyle(val label: String) {
    LIQUID_GLASS("液态玻璃·官方示例"),
    FIXED_ICON_AND_TEXT("固定·图标和文字"),
    FIXED_ICON_ONLY("固定·仅图标"),
    FIXED_SELECTED_LABEL("固定·仅选中项文字"),
    FLOATING("悬浮·仅图标")
}

val ThemeKeyColors = listOf(
    0xFFF44336, 0xFFE91E63, 0xFF9C27B0, 0xFF673AB7, 0xFF3F51B5,
    0xFF2196F3, 0xFF00BCD4, 0xFF009688, 0xFF4FAF50, 0xFFFFEB3B,
    0xFFFFC107, 0xFFFF9800, 0xFF795548, 0xFF607D8F, 0xFFFF9CA8
).map { Color(it).toArgb() }

@Stable
class AppearanceSettingsState internal constructor(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "appearance_settings",
        Context.MODE_PRIVATE
    )
    private val defaultBottomBarStyle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        BottomBarStyle.LIQUID_GLASS
    } else {
        BottomBarStyle.FIXED_ICON_AND_TEXT
    }

    var colorMode by mutableStateOf(enumPreference("color_mode", AppColorMode.SYSTEM))
        private set
    var monet by mutableStateOf(preferences.getBoolean("dynamic_color", false))
        private set
    var keyColor by mutableStateOf(preferences.getInt("key_color", 0))
        private set
    var paletteStyle by mutableStateOf(
        preferences.getString("palette_style", ThemePaletteStyle.TonalSpot.name)
            ?: ThemePaletteStyle.TonalSpot.name
    )
        private set
    var colorSpec by mutableStateOf(
        when (preferences.getString("color_spec", ThemeColorSpec.Spec2021.name)) {
            "Spec2025", "SPEC_2025" -> ThemeColorSpec.Spec2025.name
            else -> ThemeColorSpec.Spec2021.name
        }
    )
        private set
    var bottomBarStyle by mutableStateOf(
        enumPreference("bottom_bar_style", defaultBottomBarStyle)
    )
        private set
    var predictiveBack by mutableStateOf(preferences.getBoolean("predictive_back", false))
        private set
    var pageScale by mutableStateOf(preferences.getFloat("page_scale", 1f).coerceIn(1f, 1.2f))
        private set
    var animations by mutableStateOf(preferences.getBoolean("animations", true))
        private set

    private inline fun <reified T : Enum<T>> enumPreference(key: String, fallback: T): T =
        preferences.getString(key, fallback.name)
            ?.let { runCatching { enumValueOf<T>(it) }.getOrNull() }
            ?: fallback

    fun updateColorMode(value: AppColorMode) = save("color_mode", value.name) { colorMode = value }
    fun updateMonet(value: Boolean) = save("dynamic_color", value) { monet = value }
    fun updateKeyColor(value: Int) = save("key_color", value) { keyColor = value }
    fun updatePaletteStyle(value: String) = save("palette_style", value) { paletteStyle = value }
    fun updateColorSpec(value: String) = save("color_spec", value) { colorSpec = value }
    fun updateBottomBarStyle(value: BottomBarStyle) =
        save("bottom_bar_style", value.name) { bottomBarStyle = value }
    fun updatePredictiveBack(value: Boolean) = save("predictive_back", value) { predictiveBack = value }
    fun updatePageScale(value: Float) = save("page_scale", value.coerceIn(1f, 1.2f)) {
        pageScale = value.coerceIn(1f, 1.2f)
    }
    fun updateAnimations(value: Boolean) = save("animations", value) { animations = value }

    private fun save(key: String, value: Any, update: () -> Unit) {
        update()
        preferences.edit().apply {
            when (value) {
                is Boolean -> putBoolean(key, value)
                is Float -> putFloat(key, value)
                is Int -> putInt(key, value)
                is String -> putString(key, value)
            }
        }.apply()
    }

    fun reset() {
        updateColorMode(AppColorMode.SYSTEM)
        updateMonet(false)
        updateKeyColor(0)
        updatePaletteStyle(ThemePaletteStyle.TonalSpot.name)
        updateColorSpec(ThemeColorSpec.Spec2021.name)
        updateBottomBarStyle(defaultBottomBarStyle)
        updatePredictiveBack(false)
        updatePageScale(1f)
        updateAnimations(true)
    }
}

@Composable
fun rememberAppearanceSettingsState(): AppearanceSettingsState {
    val context = LocalContext.current
    return remember(context.applicationContext) { AppearanceSettingsState(context) }
}

@Composable
fun AppearanceSettingsScreen(
    state: AppearanceSettingsState,
    onBack: () -> Unit
) {
    val supportsMonet = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    val supportsPredictiveBack = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE

    ExpressivePage("界面设置", navigation = { BackButton(onBack) }) {
        item {
            SectionTitle("当前界面")
            ExpressiveCard {
                Text("即时预览", style = KitTypography.titleLarge)
                Text("更改会立即应用，并自动保存。")
                val palette = when {
                    !state.monet -> "标准配色"
                    state.keyColor == 0 -> "Monet 壁纸取色"
                    else -> "Monet 自定义主题色"
                }
                Text(
                    "当前：MIUIX · $palette",
                    style = KitTypography.headlineMedium
                )
            }
        }

        item {
            SectionTitle("颜色与 Monet")
            ExpressiveCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) {
                Column(Modifier.padding(16.dp)) {
                    ChoiceButtons(
                        values = AppColorMode.entries,
                        selected = state.colorMode,
                        label = AppColorMode::label,
                        onSelect = state::updateColorMode
                    )
                }
                SettingsToggle(
                    title = "Monet 动态配色",
                    summary = if (supportsMonet) "跟随壁纸或自定义主题色"
                    else "跟随壁纸需要 Android 12 或更高版本",
                    checked = state.monet,
                    enabled = supportsMonet,
                    onCheckedChange = state::updateMonet
                )
                AnimatedVisibility(state.monet) {
                    Column {
                        Column(
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Text("主题色", style = KitTypography.bodyLarge)
                            ThemeColorPicker(state.keyColor, state::updateKeyColor)
                        }
                        ThemeDropdown(
                            title = "调色板风格",
                            values = ThemePaletteStyle.entries.map { it.name },
                            selected = state.paletteStyle,
                            onSelect = state::updatePaletteStyle
                        )
                        ThemeDropdown(
                            title = "色彩规范",
                            values = ThemeColorSpec.entries.map { it.name },
                            selected = state.colorSpec,
                            onSelect = state::updateColorSpec
                        )
                    }
                }
            }
        }

        item {
            SectionTitle("底部导航栏")
            ExpressiveCard {
                Text("使用 MIUIX 0.9.4 官方组件与仓库中的液态玻璃示例。")
                ChoiceButtons(
                    values = BottomBarStyle.entries,
                    selected = state.bottomBarStyle,
                    label = BottomBarStyle::label,
                    onSelect = state::updateBottomBarStyle
                )
            }
        }

        item {
            SectionTitle("导航与缩放")
            ExpressiveCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) {
                if (supportsPredictiveBack) {
                    SettingsToggle(
                        title = "预测返回",
                        summary = "返回手势时预览上一层页面",
                        checked = state.predictiveBack,
                        onCheckedChange = state::updatePredictiveBack
                    )
                }
                Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                    Text("文字大小·${(state.pageScale * 100).roundToInt()}%")
                    Text("保留系统字号并额外放大，不缩小控件触控区域。", color = KitColors.onSurfaceVariant)
                    KitSlider(
                        value = state.pageScale,
                        onValueChange = state::updatePageScale,
                        valueRange = 1f..1.2f,
                        steps = 1,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                SettingsToggle(
                    title = "动画与弹性反馈",
                    summary = "页面转场、卡片按压和底栏动画",
                    checked = state.animations,
                    onCheckedChange = state::updateAnimations
                )
            }
        }

        item {
            OutlinedButton(onClick = state::reset, modifier = Modifier.fillMaxWidth()) {
                Icon(KitIcons.Restore, null)
                androidx.compose.foundation.layout.Spacer(Modifier.width(8.dp))
                Text("恢复 MIUIX 默认设置")
            }
        }
    }
}

@Composable
private fun ThemeColorPicker(selected: Int, onSelect: (Int) -> Unit) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Box(
                Modifier
                    .size(42.dp)
                    .background(KitColors.primaryContainer, CircleShape)
                    .border(
                        BorderStroke(if (selected == 0) 3.dp else 1.dp, KitColors.primary),
                        CircleShape
                    )
                    .clickable { onSelect(0) },
                contentAlignment = Alignment.Center
            ) { Text("壁纸", style = KitTypography.labelSmall) }
        }
        items(ThemeKeyColors) { value ->
            Box(
                Modifier
                    .size(42.dp)
                    .background(Color(value), CircleShape)
                    .border(
                        BorderStroke(if (selected == value) 3.dp else 1.dp, KitColors.onSurface),
                        CircleShape
                    )
                    .clickable { onSelect(value) }
            )
        }
    }
}

@Composable
private fun ThemeDropdown(
    title: String,
    values: List<String>,
    selected: String,
    onSelect: (String) -> Unit
) {
    if (LocalUseMiuix.current) {
        OverlayDropdownPreference(
            title = title,
            items = values,
            selectedIndex = values.indexOf(selected).coerceAtLeast(0),
            onSelectedIndexChange = { index -> values.getOrNull(index)?.let(onSelect) }
        )
        return
    }
    var expanded by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(title, modifier = Modifier.weight(1f))
        Box {
            TextButton(text = selected, onClick = { expanded = true })
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                values.forEach { value ->
                    DropdownMenuItem(
                        text = { Text(value) },
                        onClick = {
                            onSelect(value)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun <T> ChoiceButtons(
    values: List<T>,
    selected: T,
    label: (T) -> String,
    enabled: (T) -> Boolean = { true },
    onSelect: (T) -> Unit
) {
    FlowRow(
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        values.forEach { value ->
            if (value == selected) {
                Button(
                    onClick = { onSelect(value) },
                    enabled = enabled(value),
                    modifier = Modifier
                ) { Text(label(value)) }
            } else {
                OutlinedButton(
                    onClick = { onSelect(value) },
                    enabled = enabled(value),
                    modifier = Modifier
                ) { Text(label(value)) }
            }
        }
    }
}

@Composable
private fun SettingsToggle(
    title: String,
    summary: String,
    checked: Boolean,
    enabled: Boolean = true,
    onCheckedChange: (Boolean) -> Unit
) {
    KitSwitchPreference(
        title = title,
        summary = summary,
        checked = checked,
        enabled = enabled,
        onCheckedChange = onCheckedChange
    )
}

@Preview(
    name = "MIUIX 界面设置",
    showBackground = true,
    widthDp = 412,
    heightDp = 915
)
@Composable
private fun AppearanceSettingsScreenPreview() {
    val state = rememberAppearanceSettingsState()
    RentTheme(state) {
        AppearanceSettingsScreen(state = state, onBack = {})
    }
}
