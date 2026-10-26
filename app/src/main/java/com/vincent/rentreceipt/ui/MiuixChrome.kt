package com.vincent.rentreceipt.ui

import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.runtime.CompositionLocalProvider
import com.aritxonly.deadliner.ui.navigation.MiuixFloatingTabBar
import com.aritxonly.deadliner.ui.navigation.MiuixFloatingTabItem
import com.aritxonly.deadliner.ui.navigation.MiuixFloatingTabLayout
import com.aritxonly.deadliner.ui.theme.AdvancedMaterialSpec
import com.aritxonly.deadliner.ui.theme.LocalAdvancedMaterialSpec
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Dashboard
import androidx.compose.material.icons.rounded.MeetingRoom
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import top.yukonga.miuix.kmp.basic.FloatingNavigationBar
import top.yukonga.miuix.kmp.basic.FloatingNavigationBarItem
import top.yukonga.miuix.kmp.basic.NavigationBar
import top.yukonga.miuix.kmp.basic.NavigationBarDefaults
import top.yukonga.miuix.kmp.basic.NavigationBarDisplayMode
import top.yukonga.miuix.kmp.basic.NavigationBarItem
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme

internal data class BottomTabContent(
    val selectedTab: MainTab,
    val onTab: (MainTab) -> Unit,
    val backdrop: LayerBackdrop?,
    val modifier: Modifier
)

internal val LocalPageTabNavigation = androidx.compose.runtime.staticCompositionLocalOf<@Composable (BottomTabContent) -> Unit> {
    { content -> MiuixTabNavigation(content) }
}

@Composable
internal fun MiuixTabNavigation(content: BottomTabContent) {
    val tabs = MainTab.entries
    val items = tabs.map { tab ->
        val painter = rememberVectorPainter(tab.miuixIcon())
        MiuixFloatingTabItem(tab.name, tab.label(), painter, painter)
    }
    MiuixFloatingTabBar(
        items = items,
        selectedKey = content.selectedTab.name,
        onItemSelected = { item -> content.onTab(tabs.first { it.name == item.key }) },
        layout = MiuixFloatingTabLayout.Stacked,
        backdrop = content.backdrop,
        modifier = content.modifier
    )
}

@Composable
fun MiuixBottomBar(
    selectedTab: MainTab,
    onTab: (MainTab) -> Unit,
    backdrop: LayerBackdrop? = null,
    modifier: Modifier = Modifier,
    trailingAction: (@Composable () -> Unit)? = null
) {
    CompositionLocalProvider(LocalAdvancedMaterialSpec provides AdvancedMaterialSpec(enabled = true, blurRadius = 92f)) {
        androidx.compose.foundation.layout.Row(
            modifier = modifier.fillMaxWidth()
                .navigationBarsPadding()
                .then(if (LocalPageSearchExpanded.current) Modifier.imePadding() else Modifier).padding(horizontal = if (LocalPageSearchExpanded.current) 12.dp else 16.dp, vertical = 8.dp),
            horizontalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
        ) {
            if (LocalPageSearchExpanded.current && trailingAction != null) {
                trailingAction()
            } else {
                LocalPageTabNavigation.current.invoke(
                    BottomTabContent(
                        selectedTab, onTab, backdrop,
                        if (trailingAction != null) Modifier.weight(1f, fill = false) else Modifier
                    )
                )
                if (trailingAction != null) {
                    androidx.compose.foundation.layout.Spacer(Modifier.width(12.dp))
                    trailingAction()
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
