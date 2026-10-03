package com.vincent.rentreceipt.ui

import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.vincent.rentreceipt.MainViewModel
import com.vincent.rentreceipt.model.ReceiptTemplate
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.collect

import top.yukonga.miuix.kmp.nav.core.NavKey
import top.yukonga.miuix.kmp.nav.core.NavDisplay
import top.yukonga.miuix.kmp.nav.core.NavDisplayEffects
import top.yukonga.miuix.kmp.nav.core.rememberNavSystemCornerRadius
import top.yukonga.miuix.kmp.nav.transition.NavTransitions
import top.yukonga.miuix.kmp.nav.gesture.PredictiveBackHandler as MiuixBackHandler

sealed interface Screen : NavKey {
    data object Home : Screen
    data object AppearanceSettings : Screen
    data class Settings(val buildingId: String) : Screen
    data class RoomEditor(val buildingId: String, val roomId: String?) : Screen
    data class RoomHistory(val roomId: String) : Screen
    data class Preview(val billId: String) : Screen
}

@Composable
fun RentApp(vm: MainViewModel = viewModel()) {
    val appearanceSettings = rememberAppearanceSettingsState()
    val data by vm.data.collectAsStateWithLifecycle()
    val stack = remember { mutableStateListOf<NavKey>(Screen.Home) }
    var backProgress by remember { mutableFloatStateOf(0f) }
    var navigatingBack by remember { mutableStateOf(false) }
    var selectedTab by remember { mutableStateOf(MainTab.OVERVIEW) }
    var selectedBuildingId by remember { mutableStateOf(data.buildings.firstOrNull()?.id.orEmpty()) }
    val selectedBuilding = data.buildings.firstOrNull { it.id == selectedBuildingId }
        ?: data.buildings.firstOrNull()
    val systemDensity = LocalDensity.current
    val scaledDensity = remember(systemDensity, appearanceSettings.pageScale) {
        Density(
            density = systemDensity.density,
            fontScale = systemDensity.fontScale * appearanceSettings.pageScale
        )
    }
    val predictiveBackEnabled = appearanceSettings.predictiveBack &&
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE

    fun push(screen: Screen) {
        if (screen !in stack) {
            navigatingBack = false
            stack += screen
        }
    }
    fun pop() { if (stack.size > 1) { navigatingBack = true; stack.removeAt(stack.lastIndex) } }

    CompositionLocalProvider(LocalDensity provides scaledDensity) {
        RentTheme(appearanceSettings) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(KitColors.background)
            ) {
                val renderScreen: @Composable (Screen) -> Unit = { screen ->
                    if (LocalUseMiuix.current) {
                        // Consume back without gesture animation when the preference is off.
                        // Register before page content so dialogs retain back-event priority.
                        MiuixBackHandler(
                            enabled = !predictiveBackEnabled && stack.size > 1 && stack.last() == screen,
                            onProgress = { events -> events.collect {} },
                            onCommit = ::pop,
                            onCancel = {}
                        )
                    }
                    Box(Modifier.fillMaxSize().background(KitColors.background)) {
                        when (screen) {
                            Screen.Home -> ElectronicHome(
                                data = data,
                                selectedBuildingId = selectedBuilding?.id.orEmpty(),
                                onSelectBuilding = { selectedBuildingId = it },
                                selectedTab = selectedTab,
                                onTab = { selectedTab = it },
                                onSaveBill = vm::saveBill,
                                onMarkMonthPaid = vm::markMonthPaid,
                                onSaveBills = vm::saveBills,
                                onLoadBillDraft = vm::loadBillDraft,
                                onSaveBillDraft = vm::saveBillDraft,
                                onEditSettings = { selectedBuilding?.let { push(Screen.Settings(it.id)) } },
                                onEditAppearance = { push(Screen.AppearanceSettings) },
                                onEditRoom = { roomId -> selectedBuilding?.let { push(Screen.RoomEditor(it.id, roomId)) } },
                                onRoomHistory = { push(Screen.RoomHistory(it)) },
                                onPreview = { push(Screen.Preview(it)) },
                                onRestore = vm::replaceAll,
                                onSaveBuilding = vm::saveBuilding,
                                onDeleteBuilding = vm::deleteBuilding
                            )
                            Screen.AppearanceSettings -> AppearanceSettingsScreen(
                                state = appearanceSettings,
                                onBack = ::pop
                            )
                            is Screen.Settings -> {
                                val building = data.buildings.firstOrNull { it.id == screen.buildingId }
                                if (building != null) SettingsScreen(building.settings, onBack = ::pop) {
                                    vm.saveBuildingSettings(building.id, it)
                                    pop()
                                }
                            }
                            is Screen.RoomEditor -> {
                                val building = data.buildings.firstOrNull { it.id == screen.buildingId }
                                if (building != null) RoomEditorScreen(
                                    room = data.rooms.firstOrNull { it.id == screen.roomId },
                                    buildingId = building.id,
                                    settings = building.settings,
                                    onBack = ::pop,
                                    onSave = { vm.saveRoom(it); pop() },
                                    onDelete = { vm.deleteRoom(it); pop() }
                                )
                            }
                            is Screen.RoomHistory -> RoomHistoryScreen(
                                data = data,
                                roomId = screen.roomId,
                                onBack = ::pop,
                                onPreview = { push(Screen.Preview(it)) }
                            )
                            is Screen.Preview -> data.bills.firstOrNull { it.id == screen.billId }?.let { bill ->
                                val building = data.buildings.firstOrNull { it.id == bill.buildingId }
                                BillPreviewScreen(
                                    bill = bill,
                                    buildingName = building?.name ?: "楼栋",
                                    template = ReceiptTemplate(),
                                    onBack = ::pop
                                )
                            }
                        }
                    }
                }
                if (LocalUseMiuix.current) {
                    NavDisplay(
                        backStack = stack,
                        onBack = ::pop,
                        modifier = Modifier.fillMaxSize(),
                        transition = if (appearanceSettings.animations) {
                            NavTransitions.MiuixDefault
                        } else NavTransitions.None,
                        effects = if (appearanceSettings.animations) NavDisplayEffects(
                            cornerClipRadius = rememberNavSystemCornerRadius(),
                            backdropColor = KitColors.background
                        ) else NavDisplayEffects.None
                    ) {
                        entry<Screen.Home> { renderScreen(it) }
                        entry<Screen.AppearanceSettings> { renderScreen(it) }
                        entry<Screen.Settings> { renderScreen(it) }
                        entry<Screen.RoomEditor> { renderScreen(it) }
                        entry<Screen.RoomHistory> { renderScreen(it) }
                        entry<Screen.Preview> { renderScreen(it) }
                    }
                } else {
                    BackHandler(enabled = stack.size > 1 && !predictiveBackEnabled, onBack = ::pop)
                    PredictiveBackHandler(enabled = stack.size > 1 && predictiveBackEnabled) { progress ->
                        try {
                            progress.collect { event -> backProgress = event.progress }
                            pop()
                        } catch (_: CancellationException) {
                            // Gesture cancelled: the current page animates back to its resting position.
                        } finally {
                            backProgress = 0f
                        }
                    }

                    AnimatedContent(
                        targetState = stack.last() as Screen,
                        transitionSpec = {
                            if (appearanceSettings.animations) expressiveTransition(navigatingBack)
                            else EnterTransition.None togetherWith ExitTransition.None
                        },
                        contentKey = { it },
                        modifier = Modifier
                            .fillMaxSize()
                            .graphicsLayer {
                                val progress = if (appearanceSettings.animations) {
                                    backProgress.coerceIn(0f, 1f)
                                } else 0f
                                scaleX = 1f - progress * 0.06f
                                scaleY = 1f - progress * 0.06f
                                translationX = size.width * progress * 0.08f
                                alpha = 1f - progress * 0.08f
                            },
                        label = "page_transition"
                    ) { screen ->
                        renderScreen(screen)
                    }
                }
            }
        }
    }
}

private fun expressiveTransition(back: Boolean): ContentTransform = if (back) {
    (slideInHorizontally { -it / 8 } + fadeIn() + scaleIn(initialScale = 0.98f)) togetherWith
        (slideOutHorizontally { it / 5 } + fadeOut() + scaleOut(targetScale = 0.94f))
} else {
    (slideInHorizontally { it / 5 } + fadeIn() + scaleIn(initialScale = 0.94f)) togetherWith
        (slideOutHorizontally { -it / 8 } + fadeOut() + scaleOut(targetScale = 0.98f))
}
