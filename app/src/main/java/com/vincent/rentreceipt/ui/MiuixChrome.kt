package com.vincent.rentreceipt.ui

import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.MeetingRoom
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.vector.ImageVector
import top.yukonga.miuix.kmp.basic.FloatingNavigationBar
import top.yukonga.miuix.kmp.basic.FloatingNavigationBarItem
import top.yukonga.miuix.kmp.basic.FloatingToolbarDefaults
import top.yukonga.miuix.kmp.basic.NavigationBar
import top.yukonga.miuix.kmp.basic.NavigationBarDisplayMode
import top.yukonga.miuix.kmp.basic.NavigationBarItem
import top.yukonga.miuix.kmp.blur.BlendColorEntry
import top.yukonga.miuix.kmp.blur.BlurDefaults
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.blur.textureBlur
import top.yukonga.miuix.kmp.theme.MiuixTheme

@Composable
fun MiuixGlassBottomBar(
    selectedTab: MainTab,
    onTab: (MainTab) -> Unit,
    modifier: Modifier = Modifier,
    backdrop: LayerBackdrop? = null
) {
    val glassActive = backdrop != null && LocalGlassEffectEnabled.current
    val surface = MiuixTheme.colorScheme.surfaceContainer
    val blendColors = BlurDefaults.blurColors(
        blendColors = listOf(BlendColorEntry(surface.copy(alpha = 0.72f)))
    )
    if (LocalFloatingBottomBarEnabled.current) {
        val barModifier = if (glassActive) {
            modifier.textureBlur(
                backdrop = backdrop,
                shape = RoundedCornerShape(FloatingToolbarDefaults.CornerRadius),
                blurRadius = 28f,
                colors = blendColors
            )
        } else modifier
        FloatingNavigationBar(
            modifier = barModifier,
            color = if (glassActive) Color.Transparent else surface
        ) {
            MainTab.entries.forEach { tab ->
                FloatingNavigationBarItem(
                    selected = selectedTab == tab,
                    onClick = { onTab(tab) },
                    icon = tab.miuixIcon(),
                    label = tab.label()
                )
            }
        }
    } else {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .then(
                    if (glassActive) Modifier.textureBlur(
                        backdrop = backdrop,
                        shape = RectangleShape,
                        blurRadius = 25f,
                        colors = blendColors
                    ) else Modifier
                )
        ) {
            NavigationBar(
                modifier = Modifier.fillMaxWidth(),
                color = if (glassActive) Color.Transparent else surface,
                mode = NavigationBarDisplayMode.IconAndText
            ) {
                MainTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { onTab(tab) },
                        icon = tab.miuixIcon(),
                        label = tab.label()
                    )
                }
            }
        }
    }
}

private fun MainTab.miuixIcon(): ImageVector = when (this) {
    MainTab.OVERVIEW -> Icons.Rounded.Dashboard
    MainTab.ENTRY -> KitIcons.Notes
    MainTab.ROOMS -> Icons.Rounded.MeetingRoom
}

private fun MainTab.label(): String = when (this) {
    MainTab.OVERVIEW -> "概览"
    MainTab.ENTRY -> "录入"
    MainTab.ROOMS -> "房间"
}
