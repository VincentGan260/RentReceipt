package com.vincent.rentreceipt.ui

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.vincent.rentreceipt.R
import com.vincent.rentreceipt.data.BackupArchive
import com.vincent.rentreceipt.export.ArchivePdfExporter
import com.vincent.rentreceipt.export.ReceiptExporter
import com.vincent.rentreceipt.model.AppData
import com.vincent.rentreceipt.model.BillDraft
import com.vincent.rentreceipt.model.Building
import com.vincent.rentreceipt.model.CustomCharge
import com.vincent.rentreceipt.model.DepositStatus
import com.vincent.rentreceipt.model.ReceiptTemplate
import com.vincent.rentreceipt.model.Room
import com.vincent.rentreceipt.model.createBill
import com.vincent.rentreceipt.model.missingBillMonths
import com.vincent.rentreceipt.model.roomNumberComparator
import com.vincent.rentreceipt.model.withMergedRent
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.basic.DropdownEntry
import top.yukonga.miuix.kmp.basic.DropdownItem
import top.yukonga.miuix.kmp.menu.WindowDropdownMenu

enum class MainTab { OVERVIEW, ENTRY, ROOMS }

private data class ElectronicEntry(
    val previousWater: String,
    val currentWater: String,
    val previousElectricity: String,
    val currentElectricity: String,
    val rentOnly: Boolean = false,
    val waterUsageOverride: String = "",
    val electricityUsageOverride: String = "",
    val customCharges: List<CustomCharge> = emptyList()
)

private enum class RequiredEntryField { PREVIOUS_WATER, CURRENT_WATER, PREVIOUS_ELECTRICITY, CURRENT_ELECTRICITY }

private data class RequiredEntryKey(val roomId: String, val field: RequiredEntryField)

@Composable
fun ElectronicHome(
    data: AppData,
    selectedBuildingId: String,
    onSelectBuilding: (String) -> Unit,
    selectedTab: MainTab,
    onTab: (MainTab) -> Unit,
    onSaveBill: (com.vincent.rentreceipt.model.Bill) -> Unit,
    onMarkMonthPaid: (String, String, String) -> Unit,
    onSaveBills: (List<com.vincent.rentreceipt.model.Bill>) -> Unit,
    onLoadBillDraft: (String, String, String) -> BillDraft?,
    onSaveBillDraft: (String, String, BillDraft) -> Unit,
    onEditSettings: () -> Unit,
    onEditAppearance: () -> Unit,
    onEditRoom: (String?) -> Unit,
    onRoomHistory: (String) -> Unit,
    onPreview: (String) -> Unit,
    onRestore: (AppData) -> Unit,
    onSaveBuilding: (Building) -> Unit
) {
    var chromeVisible by remember { mutableStateOf(true) }
    val density = LocalDensity.current
    val imeVisible = WindowInsets.ime.getBottom(density) > 0
    val fixedMiuixBottomBar = LocalUseMiuix.current && !LocalFloatingBottomBarEnabled.current
    val animationsEnabled = LocalAnimationsEnabled.current
    val bottomBlurActive = android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU &&
        LocalUseMiuix.current && LocalGlobalBlurEnabled.current &&
        LocalGlassEffectEnabled.current && isRuntimeShaderSupported()
    val miuixSurface = if (LocalUseMiuix.current) MiuixTheme.colorScheme.surface else KitColors.surface
    val bottomBackdrop = if (bottomBlurActive) {
        rememberLayerBackdrop {
            drawRect(miuixSurface)
            drawContent()
        }
    } else null
    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier.fillMaxSize().then(
                if (bottomBackdrop != null) Modifier.layerBackdrop(bottomBackdrop) else Modifier
            )
        ) {
            CompositionLocalProvider(
                LocalPageScrollStateChange provides { scrolling -> chromeVisible = !scrolling }
            ) {
                AnimatedContent(
                    targetState = selectedTab,
                    transitionSpec = {
                        if (!animationsEnabled) {
                            EnterTransition.None togetherWith ExitTransition.None
                        } else if (targetState.ordinal > initialState.ordinal) {
                            (slideInHorizontally(tween(260)) { it / 7 } +
                                fadeIn(tween(220))) togetherWith
                                (slideOutHorizontally(tween(200)) { -it / 10 } +
                                    fadeOut(tween(160)))
                        } else {
                            (slideInHorizontally(tween(260)) { -it / 7 } +
                                fadeIn(tween(220))) togetherWith
                                (slideOutHorizontally(tween(200)) { it / 10 } +
                                    fadeOut(tween(160)))
                        }
                    },
                    contentKey = { it },
                    modifier = Modifier.fillMaxSize(),
                    label = "main_tab_transition"
                ) { tab ->
                when (tab) {
                    MainTab.OVERVIEW -> OverviewScreen(
                        data, selectedBuildingId, onSelectBuilding, onSaveBill,
                        onMarkMonthPaid, onRoomHistory
                    )
                    MainTab.ENTRY -> ElectronicEntryScreen(
                        data, selectedBuildingId, onSelectBuilding, onSaveBills,
                        onLoadBillDraft, onSaveBillDraft, onPreview
                    )
                    MainTab.ROOMS -> RoomManagementScreen(
                        data, selectedBuildingId, onSelectBuilding, onEditSettings,
                        onEditAppearance, onEditRoom, onRestore, onSaveBuilding
                    )
                }
                }
            }
        }
        AnimatedVisibility(
            visible = !imeVisible && (chromeVisible || fixedMiuixBottomBar),
            modifier = Modifier.align(Alignment.BottomCenter),
            enter = fadeIn() + slideInVertically { it / 2 },
            exit = fadeOut() + slideOutVertically { it / 2 }
        ) {
            if (LocalUseMiuix.current) {
                MiuixGlassBottomBar(selectedTab = selectedTab, onTab = onTab, backdrop = bottomBackdrop)
            } else Surface(
                modifier = Modifier
                    .navigationBarsPadding()
                    .padding(bottom = 8.dp)
                    .fillMaxWidth(0.78f)
                    .widthIn(max = 420.dp),
                shape = MaterialTheme.shapes.extraLarge,
                color = KitColors.surfaceContainerHigh,
                tonalElevation = 6.dp,
                shadowElevation = 10.dp
            ) {
                NavigationBar(
                    modifier = Modifier.height(72.dp),
                    containerColor = androidx.compose.ui.graphics.Color.Transparent,
                    windowInsets = WindowInsets(0, 0, 0, 0)
                ) {
                    NavigationBarItem(
                        selected = selectedTab == MainTab.OVERVIEW,
                        onClick = { onTab(MainTab.OVERVIEW) },
                        icon = { Icon(painterResource(R.drawable.ic_tab_cottage_rounded), null) },
                        label = { Text("概览") }
                    )
                    NavigationBarItem(
                        selected = selectedTab == MainTab.ENTRY,
                        onClick = { onTab(MainTab.ENTRY) },
                        icon = { Icon(painterResource(R.drawable.ic_tab_edit_note_rounded), null) },
                        label = { Text("录入") }
                    )
                    NavigationBarItem(
                        selected = selectedTab == MainTab.ROOMS,
                        onClick = { onTab(MainTab.ROOMS) },
                        icon = { Icon(painterResource(R.drawable.ic_tab_meeting_room_rounded), null) },
                        label = { Text("房间") }
                    )
                }
            }
        }
    }
}

@Composable
private fun ElectronicEntryScreen(
    data: AppData,
    selectedBuildingId: String,
    onSelectBuilding: (String) -> Unit,
    onSaveBills: (List<com.vincent.rentreceipt.model.Bill>) -> Unit,
    onLoadBillDraft: (String, String, String) -> BillDraft?,
    onSaveBillDraft: (String, String, BillDraft) -> Unit,
    onPreview: (String) -> Unit
) {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val scope = rememberCoroutineScope()
    val entryListState = rememberLazyListState()
    var readingMonth by remember { mutableStateOf(YearMonth.now()) }
    var pendingMonth by remember { mutableStateOf(readingMonth) }
    var showMonthDialog by remember { mutableStateOf(false) }
    var showMissingMonthDialog by remember { mutableStateOf(false) }
    var missingRentMonths by remember { mutableStateOf(emptyList<YearMonth>()) }
    var mergedRentMonths by remember(readingMonth, selectedBuildingId) { mutableStateOf(emptyList<YearMonth>()) }
    var message by remember { mutableStateOf<String?>(null) }
    var query by remember(selectedBuildingId) { mutableStateOf("") }
    var hasAutoSaved by remember(readingMonth, selectedBuildingId) { mutableStateOf(false) }
    var exporting by remember { mutableStateOf(false) }
    var exportedCount by remember { mutableStateOf(0) }
    val building = data.buildings.firstOrNull { it.id == selectedBuildingId } ?: data.buildings.first()
    val billMonth = readingMonth.plusMonths(1)
    val rooms = data.rooms
        .filter { it.buildingId == building.id }
        .sortedWith { left, right -> roomNumberComparator.compare(left.number, right.number) }
    val visibleRooms = rooms.filter { it.number.contains(query.trim(), ignoreCase = true) }
    val roomKey = rooms.joinToString("|") { it.id }
    val entries = remember(billMonth, roomKey, building.id) {
        mutableStateMapOf<String, ElectronicEntry>().apply {
            rooms.forEach { room ->
                val existing = data.bills.firstOrNull { it.roomId == room.id && it.month == billMonth.toString() }
                val previous = data.bills
                    .filter { it.roomId == room.id && it.month < billMonth.toString() }
                    .maxByOrNull { it.month }
                val savedDraft = onLoadBillDraft(building.id, room.id, billMonth.toString())
                put(
                    room.id,
                    ElectronicEntry(
                        previousWater = savedDraft?.previousWater
                            ?: existing?.previousWater ?: previous?.currentWater.orEmpty(),
                        currentWater = savedDraft?.currentWater ?: existing?.currentWater.orEmpty(),
                        previousElectricity = savedDraft?.previousElectricity
                            ?: existing?.previousElectricity ?: previous?.currentElectricity.orEmpty(),
                        currentElectricity = savedDraft?.currentElectricity ?: existing?.currentElectricity.orEmpty(),
                        rentOnly = false,
                        waterUsageOverride = savedDraft?.waterUsageOverride.orEmpty(),
                        electricityUsageOverride = savedDraft?.electricityUsageOverride.orEmpty(),
                        customCharges = savedDraft?.customCharges ?: existing?.customCharges.orEmpty()
                    )
                )
            }
        }
    }
    val requiredInputKeys = rooms.flatMap { room ->
        RequiredEntryField.entries.map { RequiredEntryKey(room.id, it) }
    }
    val focusRequesters = remember(roomKey) {
        rooms.flatMap { room -> RequiredEntryField.entries.map { RequiredEntryKey(room.id, it) } }
            .associateWith { FocusRequester() }
    }
    fun requiredValue(key: RequiredEntryKey): String {
        val entry = entries.getValue(key.roomId)
        return when (key.field) {
            RequiredEntryField.PREVIOUS_WATER -> entry.previousWater
            RequiredEntryField.CURRENT_WATER -> entry.currentWater
            RequiredEntryField.PREVIOUS_ELECTRICITY -> entry.previousElectricity
            RequiredEntryField.CURRENT_ELECTRICITY -> entry.currentElectricity
        }
    }
    fun focusNextEmpty(after: RequiredEntryKey) {
        val currentIndex = requiredInputKeys.indexOf(after)
        val target = requiredInputKeys.drop(currentIndex + 1).firstOrNull { requiredValue(it).isBlank() }
        if (target == null) {
            focusManager.clearFocus()
            return
        }
        val targetIsVisible = visibleRooms.any { it.id == target.roomId }
        val targetRoomIndex = if (targetIsVisible) {
            visibleRooms.indexOfFirst { it.id == target.roomId }
        } else {
            query = ""
            rooms.indexOfFirst { it.id == target.roomId }
        }
        scope.launch {
            entryListState.scrollToItem(5 + targetRoomIndex)
            withFrameNanos { }
            focusRequesters.getValue(target).requestFocus()
        }
    }
    val monthBills = data.bills.filter {
        it.buildingId == building.id && it.month == billMonth.toString()
    }.sortedWith { left, right -> roomNumberComparator.compare(left.roomNumber, right.roomNumber) }
    fun selectReadingMonth(targetReadingMonth: YearMonth) {
        val targetBillMonth = targetReadingMonth.plusMonths(1)
        val targetBillExists = data.bills.any {
            it.buildingId == building.id && it.month == targetBillMonth.toString()
        }
        val previousBillMonth = data.bills
            .filter { it.buildingId == building.id && it.month < targetBillMonth.toString() }
            .maxByOrNull { it.month }
            ?.month
        val missing = if (targetBillExists) {
            emptyList()
        } else {
            missingBillMonths(previousBillMonth, targetBillMonth.toString())
        }
        readingMonth = targetReadingMonth
        mergedRentMonths = emptyList()
        missingRentMonths = missing
        message = null
        showMissingMonthDialog = missing.isNotEmpty()
    }
    LaunchedEffect(building.id) {
        selectReadingMonth(readingMonth)
    }
    val saveJobs = remember(billMonth, building.id) { mutableMapOf<String, Job>() }
    val saveTokens = remember(billMonth, building.id) { mutableStateMapOf<String, Long>() }
    val billSaveMutex = remember(billMonth, building.id) { Mutex() }
    var saveSequence by remember(billMonth, building.id) { mutableStateOf(0L) }
    DisposableEffect(billMonth, building.id) {
        onDispose { saveJobs.values.forEach { it.cancel() } }
    }

    val updateEntry: (Room, ElectronicEntry) -> Unit = { room, updated ->
        entries[room.id] = updated
        val draft = updated.toBillDraft(billMonth).withMergedRent(room.rent, mergedRentMonths)
        onSaveBillDraft(building.id, room.id, draft)
        saveJobs.remove(room.id)?.cancel()
        val token = ++saveSequence
        saveTokens[room.id] = token
        saveJobs[room.id] = scope.launch {
            try {
                delay(450)
                val complete = listOf(
                    updated.previousWater, updated.currentWater,
                    updated.previousElectricity, updated.currentElectricity
                ).none(String::isBlank)
                if (complete) {
                    val result = withContext(Dispatchers.Default) {
                        runCatching { createBill(room, building.settings, draft) }
                    }
                    result.onSuccess { bill ->
                        withContext(Dispatchers.IO) {
                            billSaveMutex.withLock { onSaveBills(listOf(bill)) }
                        }
                        message = "已自动保存 ${room.number} 房"
                    }.onFailure {
                        message = "草稿已保存；${it.message.orEmpty()}"
                    }
                } else {
                    message = "草稿已自动保存"
                }
                hasAutoSaved = true
            } finally {
                if (saveTokens[room.id] == token) saveTokens.remove(room.id)
            }
        }
    }
    LaunchedEffect(mergedRentMonths) {
        if (mergedRentMonths.isNotEmpty()) {
            rooms.forEach { room ->
                val entry = entries.getValue(room.id)
                if (listOf(
                        entry.previousWater, entry.currentWater,
                        entry.previousElectricity, entry.currentElectricity
                    ).none(String::isBlank)
                ) updateEntry(room, entry)
            }
        }
    }

    val exportMonthReceipts: () -> Unit = {
        if (!exporting) scope.launch {
            exporting = true
            exportedCount = 0
            runCatching {
                monthBills.forEachIndexed { index, bill ->
                    withContext(Dispatchers.IO) {
                        ReceiptExporter.export(context, bill, building.name, ReceiptTemplate())
                    }
                    exportedCount = index + 1
                }
                exportedCount
            }.onSuccess { count ->
                message = "已向相册导出 $count 张收据"
                Toast.makeText(context, "已导出 $count 张收据", Toast.LENGTH_SHORT).show()
            }.onFailure {
                message = "已导出 $exportedCount 张，随后失败：${it.message}"
                Toast.makeText(context, message, Toast.LENGTH_LONG).show()
            }
            exporting = false
        }
    }

    ExpressivePage(
        title = "数据录入",
        listState = entryListState,
        actions = {
            if (monthBills.isNotEmpty()) {
                KitIconButton(
                    onClick = exportMonthReceipts,
                    enabled = !exporting
                ) {
                    Icon(
                        KitIcons.Export,
                        if (exporting) "正在导出 $exportedCount/${monthBills.size} 张收据"
                        else "导出 ${monthBills.size} 张收据"
                    )
                }
            }
        }
    ) {
        item {
            KitSearchBar(
                query = query,
                onQueryChange = { query = it },
                modifier = Modifier.fillMaxWidth(),
                label = "搜索房间号"
            )
        }
        item {
            BuildingSelector(data.buildings, building.id, onSelectBuilding)
        }
        item {
            ExpressiveCard {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    KitIconButton(onClick = {
                        selectReadingMonth(readingMonth.minusMonths(1))
                    }) {
                        Icon(KitIcons.Forward, "上个月", Modifier.rotate(180f))
                    }
                    Column(
                        Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text("${readingMonth.year} 年 ${readingMonth.monthValue} 月抄表", style = KitTypography.headlineMedium)
                        Text("生成 ${billMonth.year} 年 ${billMonth.monthValue} 月房租单")
                        Text("收据日期：${billMonth.atDay(1)}")
                        TextButton(
                            text = "选择抄表月份",
                            onClick = { pendingMonth = readingMonth; showMonthDialog = true }
                        )
                    }
                    KitIconButton(onClick = {
                        selectReadingMonth(readingMonth.plusMonths(1))
                    }) {
                        Icon(KitIcons.Forward, "下个月")
                    }
                }
            }
        }
        item(key = "auto-save-status") {
            if (exporting) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    KitLinearProgressIndicator(
                        progress = exportedCount.toFloat() / monthBills.size.coerceAtLeast(1),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Text(
                        "正在导出 $exportedCount/${monthBills.size} 张收据…",
                        color = KitColors.primary
                    )
                }
            } else if (saveTokens.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    KitLinearProgressIndicator(Modifier.fillMaxWidth())
                    Text("正在自动保存…", color = KitColors.primary)
                }
            } else if (hasAutoSaved) {
                Text(message ?: "已自动保存", color = KitColors.primary)
            }
        }
        if (rooms.isEmpty()) {
            item {
                ExpressiveCard {
                    Text("尚无房间", style = KitTypography.titleLarge)
                    Text("请先到“房间管理”新增房间。")
                }
            }
        } else if (visibleRooms.isEmpty()) {
            item {
                ExpressiveCard {
                    Text("没有找到“${query.trim()}”", style = KitTypography.titleLarge)
                    Text("请检查房间号后重试。", color = KitColors.onSurfaceVariant)
                }
            }
        } else {
            visibleRooms.forEach { room ->
                item(key = "entry-${room.id}") {
                    val entry = entries.getValue(room.id)
                    val previousWaterKey = RequiredEntryKey(room.id, RequiredEntryField.PREVIOUS_WATER)
                    val currentWaterKey = RequiredEntryKey(room.id, RequiredEntryField.CURRENT_WATER)
                    val previousElectricityKey = RequiredEntryKey(room.id, RequiredEntryField.PREVIOUS_ELECTRICITY)
                    val currentElectricityKey = RequiredEntryKey(room.id, RequiredEntryField.CURRENT_ELECTRICITY)
                    ExpressiveCard {
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text("${room.number} 房", style = KitTypography.titleLarge)
                                Text("月租 ¥${room.rent}", color = KitColors.onSurfaceVariant)
                            }
                            data.bills.firstOrNull { it.roomId == room.id && it.month == billMonth.toString() }?.let { bill ->
                                TextButton(text = "¥${bill.total}", onClick = { onPreview(bill.id) })
                            }
                        }
                        val previousBill = data.bills
                            .filter { it.roomId == room.id && it.month < billMonth.toString() }
                            .maxByOrNull { it.month }
                        val previousReadingMonth = previousBill?.let {
                            YearMonth.parse(it.month).minusMonths(1)
                        } ?: readingMonth.minusMonths(1)
                        if (mergedRentMonths.isNotEmpty()) {
                            Text(
                                "本单同时补收 ${mergedRentMonths.joinToString("、") { "${it.year}年${it.monthValue}月" }} 房租，水电按两次实际抄表读数计算。",
                                color = KitColors.primary
                            )
                        }
                            Text("水表读数", style = KitTypography.titleMedium)
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                IntegerField(
                                    "${previousReadingMonth.monthValue} 月", entry.previousWater,
                                    Modifier.weight(1f).widthIn(min = 0.dp),
                                    focusRequester = focusRequesters.getValue(previousWaterKey),
                                    onNext = { focusNextEmpty(previousWaterKey) }
                                ) {
                                    updateEntry(room, entry.copy(previousWater = it))
                                }
                                IntegerField(
                                    "${readingMonth.monthValue} 月", entry.currentWater,
                                    Modifier.weight(1f).widthIn(min = 0.dp),
                                    focusRequester = focusRequesters.getValue(currentWaterKey),
                                    onNext = { focusNextEmpty(currentWaterKey) }
                                ) {
                                    updateEntry(room, entry.copy(currentWater = it))
                                }
                            }
                        val waterWentBack = entry.currentWater.toBigDecimalOrNull()?.let { current ->
                            entry.previousWater.toBigDecimalOrNull()?.let { current < it }
                        } == true
                        if (waterWentBack) {
                            Text(
                                "水表读数变小：留空按归零上限 " +
                                    "${room.customWaterMeterMax ?: building.settings.defaultWaterMeterMax ?: "未设置"} 计算；" +
                                    "若为换表，请填写本期实际用量。",
                                color = KitColors.error
                            )
                            IntegerField(
                                "水表换表实际用量（可留空）", entry.waterUsageOverride,
                                Modifier.fillMaxWidth(), onNext = { focusNextEmpty(currentWaterKey) }
                            ) {
                                updateEntry(room, entry.copy(waterUsageOverride = it))
                            }
                        }
                        Text("电表读数", style = KitTypography.titleMedium)
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            IntegerField(
                                "${previousReadingMonth.monthValue} 月", entry.previousElectricity,
                                Modifier.weight(1f).widthIn(min = 0.dp),
                                focusRequester = focusRequesters.getValue(previousElectricityKey),
                                onNext = { focusNextEmpty(previousElectricityKey) }
                            ) {
                                updateEntry(room, entry.copy(previousElectricity = it))
                            }
                            IntegerField(
                                "${readingMonth.monthValue} 月", entry.currentElectricity,
                                Modifier.weight(1f).widthIn(min = 0.dp),
                                focusRequester = focusRequesters.getValue(currentElectricityKey),
                                onNext = { focusNextEmpty(currentElectricityKey) }
                            ) {
                                updateEntry(room, entry.copy(currentElectricity = it))
                            }
                        }
                            val electricityWentBack = entry.currentElectricity.toBigDecimalOrNull()?.let { current ->
                                entry.previousElectricity.toBigDecimalOrNull()?.let { current < it }
                            } == true
                            if (electricityWentBack) {
                                Text(
                                    "电表读数变小：留空按归零上限 " +
                                        "${room.customElectricityMeterMax ?: building.settings.defaultElectricityMeterMax ?: "未设置"} 计算；" +
                                        "若为换表，请填写本期实际用量。",
                                    color = KitColors.error
                                )
                                IntegerField(
                                    "电表换表实际用量（可留空）",
                                    entry.electricityUsageOverride,
                                    Modifier.fillMaxWidth(),
                                    onNext = { focusNextEmpty(currentElectricityKey) }
                                ) {
                                    updateEntry(room, entry.copy(electricityUsageOverride = it))
                                }
                            }
                            Row(
                                Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    "其他收费项",
                                    style = KitTypography.titleMedium,
                                    modifier = Modifier.weight(1f)
                                )
                                IconTextButton(onClick = {
                                    updateEntry(
                                        room,
                                        entry.copy(customCharges = entry.customCharges + CustomCharge())
                                    )
                                }) {
                                    Icon(painterResource(R.drawable.ic_symbol_add_rounded), null)
                                    Spacer(Modifier.width(6.dp))
                                    Text("添加", style = KitTypography.labelLarge)
                                }
                            }
                            entry.customCharges.forEachIndexed { index, charge ->
                                Column(
                                    Modifier.fillMaxWidth(),
                                    verticalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                                        KitIconButton(onClick = {
                                            updateEntry(
                                                room,
                                                entry.copy(
                                                    customCharges = entry.customCharges.filterIndexed { itemIndex, _ ->
                                                        itemIndex != index
                                                    }
                                                )
                                            )
                                        }) {
                                            Icon(
                                                KitIcons.Delete,
                                                contentDescription = "删除收费项",
                                                tint = KitColors.error
                                            )
                                        }
                                    }
                                    KitTextField(
                                        value = charge.name,
                                        onValueChange = { value ->
                                            updateEntry(
                                                room,
                                                entry.copy(
                                                    customCharges = entry.customCharges.toMutableList().apply {
                                                        this[index] = charge.copy(name = value)
                                                    }
                                                )
                                            )
                                        },
                                        label = "收费名称",
                                        singleLine = true,
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                    IntegerField(
                                        "金额",
                                        charge.amount,
                                        Modifier.fillMaxWidth()
                                    ) { value ->
                                        updateEntry(
                                            room,
                                            entry.copy(
                                                customCharges = entry.customCharges.toMutableList().apply {
                                                    this[index] = charge.copy(amount = value)
                                                }
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    if (showMonthDialog) MonthPickerDialog(
        value = pendingMonth,
        phoneDate = LocalDate.now(),
        onValue = { pendingMonth = it },
        onCancel = { showMonthDialog = false },
        onConfirm = {
            showMonthDialog = false
            selectReadingMonth(pendingMonth)
        }
    )
    if (showMissingMonthDialog) MissingMonthDialog(
        months = missingRentMonths,
        onMerge = {
            mergedRentMonths = missingRentMonths
            showMissingMonthDialog = false
        },
        onSkip = {
            mergedRentMonths = emptyList()
            showMissingMonthDialog = false
        }
    )
}

private fun ElectronicEntry.toBillDraft(month: YearMonth) = BillDraft(
    month = month.toString(),
    previousWater = previousWater,
    currentWater = currentWater,
    previousElectricity = previousElectricity,
    currentElectricity = currentElectricity,
    rentOnly = false,
    waterUsageOverride = waterUsageOverride.takeIf(String::isNotBlank),
    electricityUsageOverride = electricityUsageOverride.takeIf(String::isNotBlank),
    customCharges = customCharges
)

@Composable
fun BuildingSelector(
    buildings: List<Building>,
    selectedId: String,
    onSelect: (String) -> Unit,
    bottomAction: (@Composable () -> Unit)? = null
) {
    val selectedBuilding = buildings.firstOrNull { it.id == selectedId } ?: buildings.firstOrNull()
    val entry = DropdownEntry(
        items = buildings.map { building ->
            DropdownItem(
                text = building.name,
                selected = building.id == selectedId,
                onClick = { onSelect(building.id) }
            )
        }
    )
    ExpressiveCard(contentPadding = PaddingValues(0.dp)) {
        WindowDropdownMenu(
            entry = entry,
            title = selectedBuilding?.name ?: "选择楼栋",
            summary = "当前楼栋",
            modifier = Modifier.fillMaxWidth(),
            bottomAction = bottomAction
        )
    }
}

@Composable
private fun MonthPickerDialog(
    value: YearMonth,
    phoneDate: LocalDate,
    onValue: (YearMonth) -> Unit,
    onCancel: () -> Unit,
    onConfirm: () -> Unit
) {
    KitAlertDialog(
        onDismissRequest = onCancel,
        title = "本次录入的抄表月份？",
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("手机日期：$phoneDate")
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    KitIconButton(onClick = { onValue(value.minusMonths(1)) }) {
                        Icon(KitIcons.Forward, "上个月", Modifier.rotate(180f))
                    }
                    Text(
                        "${value.year} 年 ${value.monthValue} 月",
                        style = KitTypography.headlineSmall,
                        modifier = Modifier.weight(1f)
                    )
                    KitIconButton(onClick = { onValue(value.plusMonths(1)) }) {
                        Icon(KitIcons.Forward, "下个月")
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { onValue(YearMonth.from(phoneDate)) }) {
                        Text("本月抄表")
                    }
                    OutlinedButton(onClick = { onValue(YearMonth.from(phoneDate).minusMonths(1)) }) {
                        Text("上月抄表")
                    }
                }
                val billMonth = value.plusMonths(1)
                Text("将生成 ${billMonth.year} 年 ${billMonth.monthValue} 月房租单")
                Text("房租单日期固定为 ${billMonth.atDay(1)}")
                Text("可在任意时间选择历史月份补录。")
            }
        },
        confirmButton = {
            Button(onClick = onConfirm, modifier = Modifier.fillMaxWidth()) {
                Text("确认抄表月份", maxLines = 1)
            }
        },
        dismissButton = {
            OutlinedButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) {
                Text("取消", maxLines = 1)
            }
        }
    )
}

@Composable
private fun MissingMonthDialog(
    months: List<YearMonth>,
    onMerge: () -> Unit,
    onSkip: () -> Unit
) {
    val monthText = months.joinToString("、") { "${it.year} 年 ${it.monthValue} 月" }
    KitAlertDialog(
        // This decision changes the amount due. Outside taps and Back must not
        // silently mean "do not merge"; require one of the explicit actions.
        onDismissRequest = {},
        title = "检测到中间月份没有抄表",
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("检测到 $monthText 没有单独生成房租单。")
                Text("是否将这些月份的房租合并到本次账单？水电用量会按上次实际抄表读数与本次读数计算。")
            }
        },
        confirmButton = {
            Button(onClick = onMerge, modifier = Modifier.fillMaxWidth()) {
                Text("合并房租")
            }
        },
        dismissButton = {
            OutlinedButton(onClick = onSkip, modifier = Modifier.fillMaxWidth()) {
                Text("不合并")
            }
        }
    )
}

@Composable
private fun IntegerField(
    label: String,
    value: String,
    modifier: Modifier,
    focusRequester: FocusRequester? = null,
    onNext: (() -> Unit)? = null,
    onValue: (String) -> Unit
) {
    val focusManager = LocalFocusManager.current
    val scope = rememberCoroutineScope()
    val bringIntoViewRequester = remember { BringIntoViewRequester() }
    KitTextField(
        value = value,
        onValueChange = { input -> onValue(input.filter(Char::isDigit)) },
        label = label,
        singleLine = true,
        modifier = modifier
            .bringIntoViewRequester(bringIntoViewRequester)
            .onFocusChanged { state ->
                if (state.isFocused) scope.launch {
                    delay(250)
                    bringIntoViewRequester.bringIntoView()
                }
            }
            .then(
                if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier
            ),
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Number,
            imeAction = ImeAction.Next
        ),
        keyboardActions = KeyboardActions(
            onNext = {
                if (onNext != null) {
                    onNext()
                } else if (!focusManager.moveFocus(FocusDirection.Next)) {
                    focusManager.clearFocus()
                }
            }
        )
    )
}

@Composable
private fun RoomManagementScreen(
    data: AppData,
    selectedBuildingId: String,
    onSelectBuilding: (String) -> Unit,
    onEditSettings: () -> Unit,
    onEditAppearance: () -> Unit,
    onEditRoom: (String?) -> Unit,
    onRestore: (AppData) -> Unit,
    onSaveBuilding: (Building) -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var message by remember { mutableStateOf<String?>(null) }
    var pendingRestore by remember { mutableStateOf<AppData?>(null) }
    var buildingEditor by remember { mutableStateOf<Building?>(null) }
    var addingBuilding by remember { mutableStateOf(false) }
    var buildingName by remember { mutableStateOf("") }
    val building = data.buildings.firstOrNull { it.id == selectedBuildingId } ?: data.buildings.first()
    val rooms = data.rooms
        .filter { it.buildingId == building.id }
        .sortedWith { left, right ->
            val occupiedOrder = left.occupied.compareTo(right.occupied)
            if (occupiedOrder != 0) occupiedOrder else roomNumberComparator.compare(left.number, right.number)
        }
    val buildingBills = data.bills.filter { it.buildingId == building.id }
    var pdfStartMonth by remember(building.id) { mutableStateOf(YearMonth.of(LocalDate.now().year, 1)) }
    var pdfEndMonth by remember(building.id) { mutableStateOf(YearMonth.of(LocalDate.now().year, 12)) }
    var pdfMessage by remember(building.id) { mutableStateOf<String?>(null) }
    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip")
    ) { uri ->
        if (uri != null) scope.launch {
            message = runCatching {
                withContext(Dispatchers.IO) {
                    context.contentResolver.openOutputStream(uri, "w")?.use { BackupArchive.export(data, it) }
                        ?: error("无法创建备份文件")
                }
                "备份导出成功"
            }.getOrElse { "导出失败：${it.message}" }
        }
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) scope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(uri)?.use(BackupArchive::import)
                        ?: error("无法读取备份文件")
                }
            }.onSuccess { pendingRestore = it }
                .onFailure { message = "导入失败：${it.message}" }
        }
    }

    ExpressivePage(
        "房间管理",
        actions = { KitIconButton(onClick = onEditAppearance) { Icon(KitIcons.Settings, "界面设置") } }
    ) {
        item {
            BuildingSelector(
                buildings = data.buildings,
                selectedId = building.id,
                onSelect = onSelectBuilding,
                bottomAction = {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    OutlinedButton(
                        modifier = Modifier.weight(1f),
                        onClick = {
                            buildingEditor = building
                            buildingName = building.name
                        }
                    ) {
                        Icon(painterResource(R.drawable.ic_symbol_edit_rounded), null)
                        Spacer(Modifier.width(6.dp))
                        Text("楼栋改名", maxLines = 1)
                    }
                    Spacer(Modifier.width(8.dp))
                    Button(
                        modifier = Modifier.weight(1f),
                        onClick = {
                            addingBuilding = true
                            buildingName = ""
                        }
                    ) {
                        Icon(painterResource(R.drawable.ic_symbol_add_rounded), null)
                        Spacer(Modifier.width(6.dp))
                        Text("新增楼栋", maxLines = 1)
                    }
                }
            })
        }
        item {
            ExpressiveCard(
                onClick = onEditSettings
            ) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("默认单价", style = KitTypography.titleLarge)
                        Text(
                            "水 ¥${building.settings.defaultWaterRate} / 吨 · 电 ¥${building.settings.defaultElectricityRate} / 度",
                            color = KitColors.onSurfaceVariant
                        )
                    }
                    Text("修改", color = KitColors.primary)
                }
            }
        }
        item {
            ExpressiveCard {
                Text("房东留档 PDF", style = KitTypography.titleLarge)
                Text("按当前楼栋导出；每行一个房间，各月份显示水、电用量。")
                PdfMonthLine("开始", pdfStartMonth) { pdfStartMonth = it }
                PdfMonthLine("结束", pdfEndMonth) { pdfEndMonth = it }
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedButton(
                        onClick = {
                            val year = LocalDate.now().year
                            pdfStartMonth = YearMonth.of(year, 1)
                            pdfEndMonth = YearMonth.of(year, 12)
                        },
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("本年度")
                    }
                    Button(
                        onClick = {
                            if (rooms.isEmpty()) {
                                pdfMessage = "当前楼栋还没有房间，无法导出 PDF"
                                return@Button
                            }
                            if (pdfEndMonth.isBefore(pdfStartMonth)) {
                                pdfMessage = "结束月份不能早于开始月份"
                                return@Button
                            }
                            scope.launch {
                                pdfMessage = runCatching {
                                    withContext(Dispatchers.IO) {
                                        ArchivePdfExporter.export(
                                            context, building, rooms, buildingBills,
                                            pdfStartMonth, pdfEndMonth
                                        )
                                    }
                                    "PDF 已保存到文档/房租留档/${building.name}"
                                }.getOrElse { "PDF 导出失败：${it.message}" }
                            }
                        },
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(KitIcons.Export, null)
                        Spacer(Modifier.width(6.dp))
                        Text("导出 PDF")
                    }
                }
                pdfMessage?.let { Text(it, color = KitColors.primary) }
            }
        }
        item {
            ExpressiveCard {
                Text("完整备份与恢复", style = KitTypography.titleLarge)
                Text("ZIP 内包含全部楼栋、独立设置、房间和历史账单 CSV。恢复会覆盖当前所有数据。")
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedButton(
                        onClick = { exportLauncher.launch("房租数据备份_${LocalDate.now()}.zip") },
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(KitIcons.Export, null)
                        Spacer(Modifier.width(6.dp))
                        Text("导出 ZIP")
                    }
                    FilledTonalButton(
                        onClick = { importLauncher.launch(arrayOf("application/zip", "application/octet-stream")) },
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(KitIcons.Import, null)
                        Spacer(Modifier.width(6.dp))
                        Text("导入恢复")
                    }
                }
                message?.let { Text(it, color = KitColors.primary) }
            }
        }
        item {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("房间（${rooms.size}）", style = KitTypography.headlineMedium, modifier = Modifier.weight(1f))
                IconTextButton(onClick = { onEditRoom(null) }) {
                    Icon(painterResource(R.drawable.ic_symbol_add_rounded), null)
                    Spacer(Modifier.width(6.dp))
                    Text("新增", style = KitTypography.labelLarge)
                }
            }
        }
        rooms.forEach { room ->
            item(key = room.id) {
                ExpressiveCard(onClick = { onEditRoom(room.id) }) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("${room.number} 房", style = KitTypography.titleLarge)
                            Text(
                                "${if (room.occupied) "已出租" else "空置"}　月租 ¥${room.rent}　" +
                                    "押金 ¥${room.depositAmount}（${when (room.depositStatus) {
                                        DepositStatus.NOT_COLLECTED -> "未收"
                                        DepositStatus.COLLECTED -> "已收"
                                        DepositStatus.REFUNDED -> "已退"
                                    }}）"
                            )
                            Text(
                                "水 ¥${room.customWaterRate ?: building.settings.defaultWaterRate}　电 ¥${room.customElectricityRate ?: building.settings.defaultElectricityRate}",
                                color = KitColors.onSurfaceVariant
                            )
                        }
                        Icon(KitIcons.Forward, "编辑 ${room.number} 房")
                    }
                }
            }
        }
    }

    if (addingBuilding || buildingEditor != null) KitAlertDialog(
        onDismissRequest = { addingBuilding = false; buildingEditor = null },
        title = if (addingBuilding) "新增楼栋" else "修改楼栋名称",
        text = {
            KitTextField(
                value = buildingName,
                onValueChange = { buildingName = it },
                label = "楼栋名称",
                singleLine = true
            )
        },
        confirmButton = {
            Button(
                modifier = Modifier.fillMaxWidth(),
                enabled = buildingName.isNotBlank(),
                onClick = {
                    val saved = buildingEditor?.copy(name = buildingName.trim())
                        ?: Building(UUID.randomUUID().toString(), buildingName.trim())
                    onSaveBuilding(saved)
                    onSelectBuilding(saved.id)
                    addingBuilding = false
                    buildingEditor = null
                }
            ) { Text("保存", maxLines = 1) }
        },
        dismissButton = {
            OutlinedButton(
                onClick = { addingBuilding = false; buildingEditor = null },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("取消", maxLines = 1)
            }
        }
    )

    pendingRestore?.let { restored ->
        KitAlertDialog(
            onDismissRequest = { pendingRestore = null },
            title = "覆盖当前全部数据？",
            text = {
                Text(
                    "将恢复 ${restored.buildings.size} 栋楼、${restored.rooms.size} 个房间和 " +
                        "${restored.bills.size} 张历史账单。当前数据会被完整替换，此操作不可撤销。"
                )
            },
            confirmButton = {
                TextButton(
                    text = "确认覆盖",
                    onClick = {
                        onRestore(restored)
                        pendingRestore = null
                        message = "备份恢复完成"
                    }
                )
            },
            dismissButton = {
                TextButton(text = "取消", onClick = { pendingRestore = null })
            }
        )
    }
}

@Composable
private fun PdfMonthLine(label: String, value: YearMonth, onValue: (YearMonth) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, modifier = Modifier.weight(1f))
        KitIconButton(onClick = { onValue(value.minusMonths(1)) }) {
            Icon(KitIcons.Forward, "前一个月", Modifier.rotate(180f))
        }
        Text("%d.%02d".format(value.year, value.monthValue))
        KitIconButton(onClick = { onValue(value.plusMonths(1)) }) {
            Icon(KitIcons.Forward, "后一个月")
        }
    }
}
