package com.vincent.rentreceipt.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.vincent.rentreceipt.model.AppData
import com.vincent.rentreceipt.model.Bill
import com.vincent.rentreceipt.model.DepositStatus
import com.vincent.rentreceipt.model.resolvedElectricityUsage
import com.vincent.rentreceipt.model.resolvedWaterUsage
import com.vincent.rentreceipt.model.roomNumberComparator
import java.time.LocalDate
import java.time.YearMonth
import java.math.BigDecimal

@Composable
fun OverviewScreen(
    data: AppData,
    selectedBuildingId: String,
    onSelectBuilding: (String) -> Unit,
    onSaveBill: (Bill) -> Unit,
    onMarkMonthPaid: (String, String, String) -> Unit,
    onRoomHistory: (String) -> Unit
) {
    val building = data.buildings.firstOrNull { it.id == selectedBuildingId } ?: data.buildings.first()
    val rooms = data.rooms.filter { it.buildingId == building.id }
    val buildingBills = data.bills.filter { it.buildingId == building.id }
    val initialMonth = remember(building.id) {
        buildingBills.maxByOrNull { it.month }?.let { YearMonth.parse(it.month) }
            ?: YearMonth.now()
    }
    var month by remember(building.id) { mutableStateOf(initialMonth) }
    var query by remember(building.id) { mutableStateOf("") }
    val monthBills = buildingBills.filter { it.month == month.toString() }
    val monthBillsByRoom = monthBills.associateBy { it.roomId }
    val paidCount = monthBills.count(Bill::paid)
    val paidBills = monthBills.filter(Bill::paid)
    val collectedWater = paidBills.sumMoney { it.waterAmount }
    val collectedElectricity = paidBills.sumMoney { it.electricityAmount }
    val collectedTotal = paidBills.sumMoney { it.total }
    val visibleRooms = rooms
        .filter { it.number.contains(query.trim(), ignoreCase = true) }
        .sortedWith { left, right ->
            val paidOrder = (monthBillsByRoom[left.id]?.paid == true)
                .compareTo(monthBillsByRoom[right.id]?.paid == true)
            if (paidOrder != 0) paidOrder else roomNumberComparator.compare(left.number, right.number)
        }

    ExpressivePage("概览") {
        item {
            KitSearchBar(
                query = query,
                onQueryChange = { query = it },
                modifier = Modifier.fillMaxWidth(),
                label = "搜索房间号"
            )
        }
        item {
            BuildingSelector(
                buildings = data.buildings,
                selectedId = building.id,
                onSelect = onSelectBuilding,
                bottomAction = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    KitIconButton(onClick = { month = month.minusMonths(1) }) {
                        Icon(KitIcons.Forward, "上个月", Modifier.rotate(180f))
                    }
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("${month.year} 年 ${month.monthValue} 月", style = KitTypography.titleLarge)
                        Text("手动确认房租收缴")
                    }
                    KitIconButton(onClick = { month = month.plusMonths(1) }) {
                        Icon(KitIcons.Forward, "下个月")
                    }
                }
                if (monthBills.any { !it.paid }) {
                    FilledTonalButton(
                        onClick = {
                            onMarkMonthPaid(building.id, month.toString(), LocalDate.now().toString())
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("一键标记本月全部已收")
                    }
                }
                }
            })
        }
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StatCard("房间", rooms.size.toString(), Modifier.weight(1f))
                StatCard("已出租", rooms.count { it.occupied }.toString(), Modifier.weight(1f))
                StatCard("本月已收", "$paidCount/${monthBills.size}", Modifier.weight(1f))
            }
        }
        item {
            ExpressiveCard {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("本月已收总额", color = KitColors.onSurfaceVariant)
                        Text(
                            "水费 ¥$collectedWater · 电费 ¥$collectedElectricity",
                            color = KitColors.onSurfaceVariant
                        )
                    }
                    AdaptiveNumberText("¥$collectedTotal", expanded = true)
                }
            }
        }
        if (visibleRooms.isEmpty()) {
            item {
                ExpressiveCard {
                    if (query.isBlank()) {
                        Text("尚无房间", style = KitTypography.titleLarge)
                        Text("请先到“房间”页新增房间。", color = KitColors.onSurfaceVariant)
                    } else {
                        Text("没有找到“${query.trim()}”", style = KitTypography.titleLarge)
                        Text("请检查房间号后重试。", color = KitColors.onSurfaceVariant)
                    }
                }
            }
        }
        visibleRooms.forEach { room ->
            item(key = "overview-${room.id}") {
                val bill = monthBills.firstOrNull { it.roomId == room.id }
                ExpressiveCard(onClick = { onRoomHistory(room.id) }) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("${room.number} 房", style = KitTypography.titleLarge)
                            Text(
                                "${if (room.occupied) "已出租" else "空置"} · 租金 ¥${room.rent}",
                                color = KitColors.onSurfaceVariant
                            )
                        }
                        when {
                            bill == null -> Text("未生成账单")
                            bill.paid -> FilledTonalButton(
                                onClick = { onSaveBill(bill.copy(paid = false, paidDate = null)) }
                            ) { Text("已收 ${bill.paidDate.orEmpty()}") }
                            else -> Button(
                                onClick = {
                                    onSaveBill(
                                        bill.copy(paid = true, paidDate = LocalDate.now().toString())
                                    )
                                }
                            ) { Text("标记已收") }
                        }
                    }
                    Text(
                        "点按查看每月水电历史",
                        color = KitColors.primary,
                        style = KitTypography.labelLarge
                    )
                }
            }
        }
    }
}

@Composable
fun RoomHistoryScreen(
    data: AppData,
    roomId: String,
    onBack: () -> Unit,
    onPreview: (String) -> Unit
) {
    val room = data.rooms.firstOrNull { it.id == roomId } ?: return
    val building = data.buildings.firstOrNull { it.id == room.buildingId }
    val bills = data.bills.filter { it.roomId == room.id }.sortedByDescending { it.month }

    ExpressivePage("${room.number} 房历史", navigation = { BackButton(onBack) }) {
        item {
            ExpressiveCard {
                Text(building?.name ?: "楼栋", color = KitColors.onSurfaceVariant)
                Text("${room.number} 房", style = KitTypography.headlineMedium)
                Text(
                    "${if (room.occupied) "已出租" else "空置"} · 租金 ¥${room.rent} · " +
                        "押金 ¥${room.depositAmount}（${depositLabel(room.depositStatus)}）"
                )
                Text("共 ${bills.size} 个月账单")
            }
        }
        if (bills.isEmpty()) {
            item {
                ExpressiveCard {
                    Text("暂无历史账单", style = KitTypography.titleLarge)
                    Text("在数据录入页保存读数后，这里会按月份显示。")
                }
            }
        }
        bills.forEach { bill ->
            item(key = "history-${bill.id}") {
                ExpressiveCard(onClick = { onPreview(bill.id) }) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                YearMonth.parse(bill.month).let { "${it.year} 年 ${it.monthValue} 月" },
                                style = KitTypography.titleLarge
                            )
                            Text("房租单日期：${bill.createdDate}")
                        }
                        Text(
                            if (bill.paid) "已收 ${bill.paidDate.orEmpty()}" else "未收",
                            color = if (bill.paid) KitColors.primary
                            else KitColors.error
                        )
                    }
                    HistoryMeterLine(
                        "水表",
                        bill.previousWater,
                        bill.currentWater,
                        bill.resolvedWaterUsage()
                    )
                    HistoryMeterLine(
                        "电表",
                        bill.previousElectricity,
                        bill.currentElectricity,
                        bill.resolvedElectricityUsage()
                    )
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text("水费 ¥${bill.waterAmount}　电费 ¥${bill.electricityAmount}")
                        Text("合计 ¥${bill.total}", style = KitTypography.titleLarge)
                    }
                    bill.customCharges.forEach { charge ->
                        Text("${charge.name} ¥${charge.amount}")
                    }
                    IconTextButton(onClick = { onPreview(bill.id) }) {
                        Icon(KitIcons.Forward, null)
                        Text("查看房租单", style = KitTypography.labelLarge)
                    }
                }
            }
        }
    }
}

@Composable
private fun HistoryMeterLine(label: String, previous: String, current: String, usage: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = KitTypography.labelLarge)
        Text("$previous → $current")
        Text("用量 $usage", color = KitColors.onSurfaceVariant)
    }
}


@Composable
private fun StatCard(label: String, value: String, modifier: Modifier) {
    ExpressiveCard(modifier) {
        AdaptiveNumberText(value)
        Text(label, color = KitColors.onSurfaceVariant)
    }
}

@Composable
private fun AdaptiveNumberText(value: String, expanded: Boolean = false) {
    val length = value.length.coerceAtLeast(1)
    val fontSize = if (expanded) {
        (36 - (length - 7).coerceAtLeast(0) * 2).coerceAtLeast(18)
    } else {
        (24 - (length - 4).coerceAtLeast(0) * 2).coerceAtLeast(12)
    }
    Text(
        text = value,
        style = KitTypography.headlineMedium.copy(fontSize = fontSize.sp),
        maxLines = 1,
        overflow = TextOverflow.Clip
    )
}

private fun depositLabel(status: DepositStatus) = when (status) {
    DepositStatus.NOT_COLLECTED -> "未收"
    DepositStatus.COLLECTED -> "已收"
    DepositStatus.REFUNDED -> "已退"
}

private fun List<Bill>.sumMoney(value: (Bill) -> String): String =
    fold(BigDecimal.ZERO) { total, bill -> total + (value(bill).toBigDecimalOrNull() ?: BigDecimal.ZERO) }
        .setScale(0, java.math.RoundingMode.HALF_UP)
        .toPlainString()
