package com.vincent.rentreceipt.ui

import top.yukonga.miuix.kmp.basic.DropdownEntry
import top.yukonga.miuix.kmp.basic.DropdownItem
import top.yukonga.miuix.kmp.menu.WindowDropdownMenu
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
    LIQUID_GLASS("柔光玻璃·HyperModifier"),
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
    init {
        if (!preferences.getBoolean("content_animation_fix_applied", false)) {
            preferences.edit().putBoolean("animations", true)
                .putBoolean("content_animation_fix_applied", true).apply()
        }
    }
    private val defaultBottomBarStyle = BottomBarStyle.LIQUID_GLASS

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
    var showLicenses by remember { mutableStateOf(false) }
    if (showLicenses) AboutDialog(onDismiss = { showLicenses = false })
    val supportsPredictiveBack = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE

    ExpressivePage("界面设置", navigation = { BackButton(onBack) }) {
        item {
            ExpressiveCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 16.dp, horizontal = 0.dp)) {
                Text("外观", color = KitColors.onSurface, style = KitTypography.titleLarge, modifier = Modifier.padding(horizontal = 16.dp))
                WindowDropdownMenu(
                    entry = DropdownEntry(items = AppColorMode.entries.map { mode ->
                        DropdownItem(text = mode.label, selected = state.colorMode == mode,
                            onClick = { state.updateColorMode(mode) })
                    }),
                    title = "显示模式", summary = state.colorMode.label,
                    modifier = Modifier.fillMaxWidth()
                )
                com.aritxonly.myhypermodifier.SettingsSliderItemWithLabel(
                    label = "界面大小", value = state.pageScale, valueRange = 1f..1.2f,
                    steps = 1, valueText = { "${(it * 100).roundToInt()}%" },
                    onValueChange = state::updatePageScale
                )
            }
        }
        item {
            ExpressiveCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 16.dp, horizontal = 0.dp)) {
                Text("交互", color = KitColors.onSurface, style = KitTypography.titleLarge, modifier = Modifier.padding(horizontal = 16.dp))
                if (supportsPredictiveBack) {
                    com.aritxonly.myhypermodifier.SettingsSwitchItem(
                        label = "预测返回", supportingText = "返回时预览上一页",
                        checked = state.predictiveBack, onCheckedChange = state::updatePredictiveBack
                    )
                }
                com.aritxonly.myhypermodifier.SettingsSwitchItem(
                    label = "动画与弹性反馈", supportingText = "页面过渡与控件反馈",
                    checked = state.animations, onCheckedChange = state::updateAnimations
                )
                com.aritxonly.myhypermodifier.SettingItem(
                    headlineText = "恢复默认设置", supportingText = "恢复配色模式、界面大小及交互设置",
                    trailingContent = { Icon(KitIcons.Restore, null, tint = KitColors.onSurfaceVariant) },
                    onClick = state::reset
                )
            }
        }
        item {
            ExpressiveCard(contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 16.dp, horizontal = 0.dp)) {
                Text("关于", color = KitColors.onSurface, style = KitTypography.titleLarge, modifier = Modifier.padding(horizontal = 16.dp))
                com.aritxonly.myhypermodifier.SettingItem(
                    headlineText = "关于房租单生成", supportingText = "版本信息、开源技术与许可",
                    trailingContent = { Icon(KitIcons.Forward, null, tint = KitColors.onSurfaceVariant) },
                    onClick = { showLicenses = true }
                )
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
