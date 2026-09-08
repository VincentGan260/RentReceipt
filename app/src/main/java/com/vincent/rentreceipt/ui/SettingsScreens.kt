package com.vincent.rentreceipt.ui

import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.vincent.rentreceipt.export.ReceiptExporter
import com.vincent.rentreceipt.model.Bill
import com.vincent.rentreceipt.model.DepositStatus
import com.vincent.rentreceipt.model.PricingSettings
import com.vincent.rentreceipt.model.Room
import com.vincent.rentreceipt.model.ReceiptTemplate
import com.vincent.rentreceipt.model.resolvedElectricityUsage
import com.vincent.rentreceipt.model.resolvedWaterUsage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import java.time.LocalDate

@Composable
fun BackButton(onBack: () -> Unit) = KitIconButton(onClick = onBack) {
    Icon(KitIcons.Back, "返回", Modifier.size(28.dp))
}

@Composable
fun SettingsScreen(settings: PricingSettings, onBack: () -> Unit, onSave: (PricingSettings) -> Unit) {
    var water by remember { mutableStateOf(settings.defaultWaterRate) }
    var electricity by remember { mutableStateOf(settings.defaultElectricityRate) }
    var waterMeterMax by remember { mutableStateOf(settings.defaultWaterMeterMax.orEmpty()) }
    var electricityMeterMax by remember { mutableStateOf(settings.defaultElectricityMeterMax.orEmpty()) }
    var error by remember { mutableStateOf<String?>(null) }
    ExpressivePage("收费设置", navigation = { BackButton(onBack) }) {
        item {
            ExpressiveCard {
                Text("默认水电单价", style = KitTypography.headlineMedium)
                Text("房间没有单独设置时使用这里的价格。", color = KitColors.onSurfaceVariant)
                NumberField("水费（元/吨）", water) { water = it }
                NumberField("电费（元/度）", electricity) { electricity = it }
            }
        }
        item {
            ExpressiveCard {
                Text("表具归零上限", style = KitTypography.headlineMedium)
                Text("读数从上限归零时用于计算实际用量；留空表示不自动处理。")
                NumberField("水表上限（可留空）", waterMeterMax) { waterMeterMax = it }
                NumberField("电表上限（例如10000）", electricityMeterMax) { electricityMeterMax = it }
            }
        }
        error?.let { item { Text(it, color = KitColors.error) } }
        item {
            Button(onClick = {
                if (
                    water.toBigDecimalOrNull() == null || electricity.toBigDecimalOrNull() == null ||
                    (waterMeterMax.isNotBlank() && waterMeterMax.toBigDecimalOrNull() == null) ||
                    (electricityMeterMax.isNotBlank() && electricityMeterMax.toBigDecimalOrNull() == null)
                ) error = "请输入有效的单价和表具上限"
                else onSave(
                    PricingSettings(
                        water,
                        electricity,
                        waterMeterMax.takeIf(String::isNotBlank),
                        electricityMeterMax.takeIf(String::isNotBlank)
                    )
                )
            }, modifier = Modifier.fillMaxWidth()) {
                Icon(KitIcons.Save, null)
                Spacer(Modifier.width(8.dp))
                Text("保存默认价格")
            }
        }
    }
}

@Composable
fun RoomEditorScreen(
    room: Room?, buildingId: String, settings: PricingSettings, onBack: () -> Unit,
    onSave: (Room) -> Unit, onDelete: (String) -> Unit
) {
    var number by remember { mutableStateOf(room?.number ?: "") }
    var rent by remember { mutableStateOf(room?.rent ?: "") }
    var customWater by remember { mutableStateOf(room?.customWaterRate != null) }
    var water by remember { mutableStateOf(room?.customWaterRate ?: settings.defaultWaterRate) }
    var customElectricity by remember { mutableStateOf(room?.customElectricityRate != null) }
    var electricity by remember { mutableStateOf(room?.customElectricityRate ?: settings.defaultElectricityRate) }
    var customWaterMeterMax by remember { mutableStateOf(room?.customWaterMeterMax != null) }
    var waterMeterMax by remember {
        mutableStateOf(room?.customWaterMeterMax ?: settings.defaultWaterMeterMax.orEmpty())
    }
    var customElectricityMeterMax by remember { mutableStateOf(room?.customElectricityMeterMax != null) }
    var electricityMeterMax by remember {
        mutableStateOf(room?.customElectricityMeterMax ?: settings.defaultElectricityMeterMax.orEmpty())
    }
    var occupied by remember { mutableStateOf(room?.occupied ?: false) }
    var depositAmount by remember { mutableStateOf(room?.depositAmount ?: "0") }
    var depositStatus by remember { mutableStateOf(room?.depositStatus ?: DepositStatus.NOT_COLLECTED) }
    var depositCollectedDate by remember { mutableStateOf(room?.depositCollectedDate) }
    var depositRefundedDate by remember { mutableStateOf(room?.depositRefundedDate) }
    var confirmDelete by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val saveRoom = {
        if (
            number.isBlank() || rent.toBigDecimalOrNull() == null ||
            depositAmount.toBigDecimalOrNull() == null ||
            (customWaterMeterMax && waterMeterMax.toBigDecimalOrNull() == null) ||
            (customElectricityMeterMax && electricityMeterMax.toBigDecimalOrNull() == null)
        ) error = "请填写有效的房号、月租和押金"
        else onSave(
            Room(
                id = room?.id ?: UUID.randomUUID().toString(),
                number = number.trim(),
                rent = rent,
                customWaterRate = water.takeIf { customWater },
                customElectricityRate = electricity.takeIf { customElectricity },
                buildingId = buildingId,
                occupied = occupied,
                depositAmount = depositAmount,
                depositStatus = depositStatus,
                depositCollectedDate = depositCollectedDate,
                depositRefundedDate = depositRefundedDate,
                customWaterMeterMax = waterMeterMax.takeIf { customWaterMeterMax },
                customElectricityMeterMax = electricityMeterMax.takeIf { customElectricityMeterMax }
            )
        )
    }
    ExpressivePage(if (room == null) "新增房间" else "${room.number} 房", navigation = { BackButton(onBack) }) {
        item {
            ExpressiveCard {
                TextField("房号", number) { number = it }
                NumberField("月租（元）", rent) { rent = it }
                ToggleLine("已出租", occupied) { occupied = it }
            }
        }
        item {
            ExpressiveCard {
                Text("押金", style = KitTypography.titleLarge)
                NumberField("押金金额（元）", depositAmount) { depositAmount = it }
                FlowRow(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    DepositStatus.entries.forEach { status ->
                        val label = when (status) {
                            DepositStatus.NOT_COLLECTED -> "未收"
                            DepositStatus.COLLECTED -> "已收"
                            DepositStatus.REFUNDED -> "已退"
                        }
                        if (status == depositStatus) Button(
                            onClick = {}
                        ) { Text(label) } else OutlinedButton(
                            onClick = {
                                depositStatus = status
                                val today = LocalDate.now().toString()
                                if (status == DepositStatus.COLLECTED) depositCollectedDate = today
                                if (status == DepositStatus.REFUNDED) depositRefundedDate = today
                            }
                        ) { Text(label) }
                    }
                }
                depositCollectedDate?.let { Text("收取日期：$it") }
                depositRefundedDate?.let { Text("退还日期：$it") }
            }
        }
        error?.let { item { Text(it, color = KitColors.error) } }
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (room != null) {
                    OutlinedButton(
                        onClick = { confirmDelete = true },
                        modifier = Modifier.weight(1f),
                        destructive = true
                    ) {
                        Icon(KitIcons.Delete, null)
                        Spacer(Modifier.width(8.dp))
                        Text("删除")
                    }
                }
                Button(
                    onClick = saveRoom,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(KitIcons.Save, null)
                    Spacer(Modifier.width(8.dp))
                    Text("保存")
                }
            }
        }
        item {
            ExpressiveCard {
                ToggleLine("自定义水价", customWater) { customWater = it }
                if (customWater) NumberField("水费（元/吨）", water) { water = it }
                else Text("使用默认 ¥${settings.defaultWaterRate}")
                ToggleLine("自定义电价", customElectricity) { customElectricity = it }
                if (customElectricity) NumberField("电费（元/度）", electricity) { electricity = it }
                else Text("使用默认 ¥${settings.defaultElectricityRate}")
                ToggleLine("自定义水表归零上限", customWaterMeterMax) { customWaterMeterMax = it }
                if (customWaterMeterMax) NumberField("水表上限", waterMeterMax) { waterMeterMax = it }
                else Text("使用楼栋设置 ${settings.defaultWaterMeterMax ?: "未设置"}")
                ToggleLine("自定义电表归零上限", customElectricityMeterMax) {
                    customElectricityMeterMax = it
                }
                if (customElectricityMeterMax) {
                    NumberField("电表上限", electricityMeterMax) { electricityMeterMax = it }
                } else Text("使用楼栋设置 ${settings.defaultElectricityMeterMax ?: "未设置"}")
            }
        }
    }
    if (confirmDelete && room != null) KitAlertDialog(
        onDismissRequest = { confirmDelete = false },
        title = "删除 ${room.number} 房？",
        text = { Text("历史账单仍会保留。") },
        confirmButton = { TextButton(text = "删除", onClick = { onDelete(room.id) }) },
        dismissButton = { TextButton(text = "取消", onClick = { confirmDelete = false }) }
    )
}

@Composable
private fun ToggleLine(label: String, checked: Boolean, onChecked: (Boolean) -> Unit) {
    KitSwitchPreference(title = label, checked = checked, onCheckedChange = onChecked)
}

@Composable
fun BillPreviewScreen(
    bill: Bill,
    buildingName: String,
    template: ReceiptTemplate,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var exported by remember { mutableStateOf<Uri?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    val preview = remember(bill, template) {
        ReceiptExporter.createPreviewBitmap(context, bill, template)
    }
    DisposableEffect(preview) {
        onDispose { preview.recycle() }
    }
    ExpressivePage("${bill.roomNumber} 房 · ${bill.month}", navigation = { BackButton(onBack) }) {
        item {
            ExpressiveCard {
                Text("房租单预览", style = KitTypography.titleLarge)
                Text("文字会自动缩小到表格范围内，保存图片与此预览一致。")
                Image(
                    bitmap = preview.asImageBitmap(),
                    contentDescription = "房租单最终效果预览",
                    modifier = Modifier.fillMaxWidth().aspectRatio(
                        ReceiptExporter.WIDTH.toFloat() / ReceiptExporter.heightFor(bill)
                    )
                )
            }
        }
        item {
            ExpressiveCard {
                Text("应收合计", color = KitColors.onSurfaceVariant)
                Text("¥${bill.total}", style = KitTypography.displaySmall)
                BillLine("房租", bill.rent)
                BillLine("水费 · 用量 ${bill.resolvedWaterUsage()}", bill.waterAmount)
                BillLine("电费 · 用量 ${bill.resolvedElectricityUsage()}", bill.electricityAmount)
                bill.customCharges.forEach { charge ->
                    BillLine(charge.name, charge.amount)
                }
            }
        }
        item {
            Button(onClick = {
                scope.launch {
                    runCatching {
                        withContext(Dispatchers.IO) {
                            ReceiptExporter.export(context, bill, buildingName, template)
                        }
                    }
                        .onSuccess { exported = it; message = "已保存到相册" }
                        .onFailure { message = it.message ?: "保存失败" }
                }
            }, modifier = Modifier.fillMaxWidth()) {
                Icon(KitIcons.Save, null)
                Spacer(Modifier.width(8.dp))
                Text("保存高清图片")
            }
        }
        item {
            OutlinedButton(onClick = {
                val uri = exported
                if (uri != null) ReceiptExporter.share(context, uri) else message = "请先保存图片"
            }, modifier = Modifier.fillMaxWidth()) {
                Icon(KitIcons.Share, null)
                Spacer(Modifier.width(8.dp))
                Text("分享图片")
            }
        }
        message?.let { item { Text(it, color = KitColors.primary) } }
    }
}

@Composable
private fun BillLine(label: String, amount: String) {
    Row(Modifier.fillMaxWidth()) { Text(label, Modifier.weight(1f)); Text("¥$amount") }
}
