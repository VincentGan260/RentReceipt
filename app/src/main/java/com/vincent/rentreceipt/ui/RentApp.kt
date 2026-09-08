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

sealed interface Screen {
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
    val stack = remember { mutableStateListOf<Screen>(Screen.Home) }
    var backProgress by remember { mutableFloatStateOf(0f) }
    var navigatingBack by remember { mutableStateOf(false) }
    var selectedTab by remember { mutableStateOf(MainTab.OVERVIEW) }
    var selectedBuildingId by remember { mutableStateOf(data.buildings.first().id) }
    val selectedBuilding = data.buildings.firstOrNull { it.id == selectedBuildingId } ?: data.buildings.first()
    val systemDensity = LocalDensity.current
    val scaledDensity = remember(systemDensity, appearanceSettings.pageScale) {
        Density(
            density = systemDensity.density,
            fontScale = systemDensity.fontScale * appearanceSettings.pageScale
        )
    }
    val predictiveBackEnabled = appearanceSettings.predictiveBack &&
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE

    fun push(screen: Screen) { navigatingBack = false; stack += screen }
    fun pop() { if (stack.size > 1) { navigatingBack = true; stack.removeAt(stack.lastIndex) } }

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

    CompositionLocalProvider(LocalDensity provides scaledDensity) {
    RentTheme(appearanceSettings) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(KitColors.background)
        ) {
            AnimatedContent(
                targetState = stack.last(),
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
                when (screen) {
                Screen.Home -> ElectronicHome(
                    data = data,
                    selectedBuildingId = selectedBuilding.id,
                    onSelectBuilding = { selectedBuildingId = it },
                    selectedTab = selectedTab,
                    onTab = { selectedTab = it },
                    onSaveBill = vm::saveBill,
                    onMarkMonthPaid = vm::markMonthPaid,
                    onSaveBills = vm::saveBills,
                    onLoadBillDraft = vm::loadBillDraft,
                    onSaveBillDraft = vm::saveBillDraft,
                    onEditSettings = { push(Screen.Settings(selectedBuilding.id)) },
                    onEditAppearance = { push(Screen.AppearanceSettings) },
                    onEditRoom = { push(Screen.RoomEditor(selectedBuilding.id, it)) },
                    onRoomHistory = { push(Screen.RoomHistory(it)) },
                    onPreview = { push(Screen.Preview(it)) },
                    onRestore = vm::replaceAll,
                    onSaveBuilding = vm::saveBuilding
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
                    onSave = { vm.saveRoom(it); pop() }, onDelete = { vm.deleteRoom(it); pop() })
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
