package com.vincent.rentreceipt.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.MeetingRoom
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import component.liquid.IosLiquidGlassNavigationBar
import top.yukonga.miuix.kmp.basic.FloatingNavigationBar
import top.yukonga.miuix.kmp.basic.FloatingNavigationBarItem
import top.yukonga.miuix.kmp.basic.NavigationBar
import top.yukonga.miuix.kmp.basic.NavigationBarDefaults
import top.yukonga.miuix.kmp.basic.NavigationBarDisplayMode
import top.yukonga.miuix.kmp.basic.NavigationBarItem
import top.yukonga.miuix.kmp.basic.NavigationItem
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme

@Composable
fun MiuixBottomBar(
    selectedTab: MainTab,
    onTab: (MainTab) -> Unit,
    backdrop: LayerBackdrop? = null,
    modifier: Modifier = Modifier
) {
    val style = LocalBottomBarStyle.current
    val itemColors = NavigationBarDefaults.navigationBarItemColors(
        selectedContentColor = MiuixTheme.colorScheme.primary,
        unselectedContentColor = MiuixTheme.colorScheme.onSurfaceContainer
    )

    if (style == BottomBarStyle.LIQUID_GLASS) {
        val tabs = MainTab.entries
        IosLiquidGlassNavigationBar(
            items = tabs.map { NavigationItem(it.label(), it.miuixIcon()) },
            selectedIndex = tabs.indexOf(selectedTab),
            onItemClick = { index -> onTab(tabs[index]) },
            backdrop = backdrop,
            isBlurActive = backdrop != null,
            modifier = modifier
        )
        return
    }

    if (style == BottomBarStyle.FLOATING) {
        FloatingNavigationBar(modifier = modifier) {
            MainTab.entries.forEach { tab ->
                FloatingNavigationBarItem(
                    selected = selectedTab == tab,
                    onClick = { onTab(tab) },
                    icon = tab.miuixIcon(),
                    label = tab.label(),
                    colors = itemColors
                )
            }
        }
        return
    }

    val displayMode = when (style) {
        BottomBarStyle.FIXED_ICON_AND_TEXT -> NavigationBarDisplayMode.IconAndText
        BottomBarStyle.FIXED_ICON_ONLY -> NavigationBarDisplayMode.IconOnly
        BottomBarStyle.FIXED_SELECTED_LABEL -> NavigationBarDisplayMode.IconWithSelectedLabel
        BottomBarStyle.FLOATING -> error("Handled above")
        BottomBarStyle.LIQUID_GLASS -> error("Handled above")
    }
    Box(modifier = modifier.fillMaxWidth()) {
        NavigationBar(
            modifier = Modifier.fillMaxWidth(),
            mode = displayMode
        ) {
            MainTab.entries.forEach { tab ->
                NavigationBarItem(
                    selected = selectedTab == tab,
                    onClick = { onTab(tab) },
                    icon = tab.miuixIcon(),
                    label = tab.label(),
                    colors = itemColors
                )
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
