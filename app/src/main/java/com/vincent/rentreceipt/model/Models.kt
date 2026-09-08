package com.vincent.rentreceipt.model

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

const val DEFAULT_BUILDING_ID = "default-building"

data class PricingSettings(
    val defaultWaterRate: String = "5.00",
    val defaultElectricityRate: String = "1.30",
    val defaultWaterMeterMax: String? = null,
    val defaultElectricityMeterMax: String? = "10000"
)

data class ReceiptTextElement(
    val id: String,
    val content: String,
    val x: Float,
    val y: Float,
    val fontSize: Float,
    val centered: Boolean = false,
    val color: String = "body"
)

data class ReceiptTemplate(
    val elements: List<ReceiptTextElement> = defaultReceiptElements()
)

data class Building(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val settings: PricingSettings = PricingSettings(),
    val receiptTemplate: ReceiptTemplate? = null
)

enum class DepositStatus { NOT_COLLECTED, COLLECTED, REFUNDED }

data class Room(
    val id: String = UUID.randomUUID().toString(),
    val number: String,
    val rent: String,
    val customWaterRate: String? = null,
    val customElectricityRate: String? = null,
    val buildingId: String = DEFAULT_BUILDING_ID,
    val occupied: Boolean = false,
    val depositAmount: String = "0",
    val depositStatus: DepositStatus = DepositStatus.NOT_COLLECTED,
    val depositCollectedDate: String? = null,
    val depositRefundedDate: String? = null,
    val customWaterMeterMax: String? = null,
    val customElectricityMeterMax: String? = null
)

data class Bill(
    val id: String = UUID.randomUUID().toString(),
    val buildingId: String = DEFAULT_BUILDING_ID,
    val roomId: String,
    val roomNumber: String,
    val month: String,
    val createdDate: String = LocalDate.now().toString(),
    val previousWater: String,
    val currentWater: String,
    val waterRate: String,
    val waterAmount: String,
    val previousElectricity: String,
    val currentElectricity: String,
    val electricityRate: String,
    val electricityAmount: String,
    val rent: String,
    val total: String,
    val rentOnly: Boolean = false,
    val paid: Boolean = false,
    val paidDate: String? = null,
    val waterUsage: String = "",
    val electricityUsage: String = "",
    val customCharges: List<CustomCharge> = emptyList()
)

data class CustomCharge(
    val name: String = "",
    val amount: String = ""
)

data class AppData(
    val buildings: List<Building> = listOf(Building(DEFAULT_BUILDING_ID, "默认楼栋")),
    val rooms: List<Room> = emptyList(),
    val bills: List<Bill> = emptyList(),
    val receiptTemplate: ReceiptTemplate = ReceiptTemplate()
) {
    val settings: PricingSettings
        get() = buildings.firstOrNull()?.settings ?: PricingSettings()
}

fun defaultReceiptElements(): List<ReceiptTextElement> = listOf(
    ReceiptTextElement("title", "公寓房租、水、电费（专用）收据", 1754f, 125f, 108f, true),
    ReceiptTextElement("userLabel", "用户名称：", 95f, 245f, 66f),
    ReceiptTextElement("room", "{room}", 405f, 245f, 148f, color = "blue"),
    ReceiptTextElement("roomSuffix", "号", 700f, 245f, 66f),
    ReceiptTextElement("receiptNo", "№  {receiptNo}", 2760f, 150f, 76f, color = "red"),
    ReceiptTextElement("date", "{date}", 2700f, 265f, 90f, color = "blue"),
    ReceiptTextElement("headItem", "项  目", 337f, 435f, 66f, true),
    ReceiptTextElement("headCurrent", "本  月", 777f, 435f, 66f, true),
    ReceiptTextElement("headPrevious", "上  月", 1172f, 435f, 66f, true),
    ReceiptTextElement("headUsage", "实  用", 1567f, 435f, 66f, true),
    ReceiptTextElement("headAmount", "金      额", 2799f, 435f, 66f, true),
    ReceiptTextElement("waterLabel", "水费（立方米）", 337f, 700f, 66f, true),
    ReceiptTextElement("waterCurrent", "{currentWater}", 777f, 720f, 136f, true, "blue"),
    ReceiptTextElement("waterPrevious", "{previousWater}", 1172f, 720f, 136f, true, "blue"),
    ReceiptTextElement("waterUsage", "{waterUsage}", 1567f, 720f, 136f, true, "blue"),
    ReceiptTextElement("waterAmount", "{waterAmount}", 2799f, 725f, 136f, true, "blue"),
    ReceiptTextElement("electricLabel", "电费（度）", 337f, 1000f, 66f, true),
    ReceiptTextElement("electricCurrent", "{currentElectricity}", 777f, 1020f, 136f, true, "blue"),
    ReceiptTextElement("electricPrevious", "{previousElectricity}", 1172f, 1020f, 136f, true, "blue"),
    ReceiptTextElement("electricUsage", "{electricityUsage}", 1567f, 1020f, 136f, true, "blue"),
    ReceiptTextElement("electricAmount", "{electricityAmount}", 2799f, 1025f, 136f, true, "blue"),
    ReceiptTextElement("rentLabel", "房  租", 337f, 1300f, 66f, true),
    ReceiptTextElement("rentUsage", "{rent}", 1567f, 1325f, 136f, true, "blue"),
    ReceiptTextElement("rentAmount", "{rent}", 2799f, 1325f, 136f, true, "blue"),
    ReceiptTextElement("totalLabel", "合  计（大写）", 155f, 1635f, 64f),
    ReceiptTextElement("totalUpper", "{totalUpper}", 720f, 1695f, 140f, color = "blue"),
    ReceiptTextElement("total", "¥ {total}", 2720f, 1705f, 168f, color = "blue")
)

val roomNumberComparator: Comparator<String> =
    compareBy<String>(
        { if (it.trim().startsWith("铺") || it.trim().startsWith("店")) 0 else 1 },
        { it.filter(Char::isDigit).toIntOrNull() ?: Int.MAX_VALUE },
        { it }
    )

data class BillDraft(
    val month: String = YearMonth.now().toString(),
    val previousWater: String = "",
    val currentWater: String = "",
    val previousElectricity: String = "",
    val currentElectricity: String = "",
    val rentOnly: Boolean = false,
    val waterUsageOverride: String? = null,
    val electricityUsageOverride: String? = null,
    val customCharges: List<CustomCharge> = emptyList()
)

data class BillCalculation(
    val waterUsage: BigDecimal,
    val electricityUsage: BigDecimal,
    val waterAmount: BigDecimal,
    val electricityAmount: BigDecimal,
    val total: BigDecimal
)

fun calculateBill(room: Room, settings: PricingSettings, draft: BillDraft): BillCalculation {
    val customChargeTotal = draft.customCharges.sumOf { charge ->
        require(charge.name.isNotBlank() && charge.amount.isNotBlank()) { "请填写其他收费项的名称和金额" }
        val amount = charge.amount.toDecimal()
        require(amount >= BigDecimal.ZERO) { "其他收费项金额不能为负数" }
        amount.whole()
    }
    if (draft.rentOnly) {
        require(draft.currentWater.isNotBlank() && draft.currentElectricity.isNotBlank()) {
            "请填写入住时的水电表读数"
        }
        require(draft.currentWater.toDecimal() >= BigDecimal.ZERO && draft.currentElectricity.toDecimal() >= BigDecimal.ZERO) {
            "入住时的水电表读数不能为负数"
        }
        val rent = room.rent.toDecimal()
        require(rent >= BigDecimal.ZERO) { "房租不能为负数" }
        return BillCalculation(
            BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
            (rent + customChargeTotal).whole()
        )
    }
    require(
        draft.previousWater.isNotBlank() && draft.currentWater.isNotBlank() &&
            draft.previousElectricity.isNotBlank() && draft.currentElectricity.isNotBlank()
    ) { "请填写完整的本月和上月水电读数" }
    val previousWater = draft.previousWater.toDecimal()
    val currentWater = draft.currentWater.toDecimal()
    val previousElectricity = draft.previousElectricity.toDecimal()
    val currentElectricity = draft.currentElectricity.toDecimal()
    val waterUsage = meterUsage(
        previousWater, currentWater,
        room.customWaterMeterMax ?: settings.defaultWaterMeterMax,
        draft.waterUsageOverride,
        "水表"
    )
    val electricityUsage = meterUsage(
        previousElectricity, currentElectricity,
        room.customElectricityMeterMax ?: settings.defaultElectricityMeterMax,
        draft.electricityUsageOverride,
        "电表"
    )
    val waterRate = (room.customWaterRate ?: settings.defaultWaterRate).toDecimal()
    val electricityRate = (room.customElectricityRate ?: settings.defaultElectricityRate).toDecimal()
    require(waterRate >= BigDecimal.ZERO && electricityRate >= BigDecimal.ZERO) { "水电单价不能为负数" }
    require(room.rent.toDecimal() >= BigDecimal.ZERO) { "房租不能为负数" }
    val waterAmount = (waterUsage * waterRate).whole()
    val electricityAmount = (electricityUsage * electricityRate).whole()
    val total = room.rent.toDecimal() + waterAmount + electricityAmount + customChargeTotal
    return BillCalculation(waterUsage.whole(), electricityUsage.whole(), waterAmount, electricityAmount, total.whole())
}

fun createBill(room: Room, settings: PricingSettings, draft: BillDraft): Bill {
    val value = calculateBill(room, settings, draft)
    val previousWater = if (draft.rentOnly) draft.currentWater else draft.previousWater
    val previousElectricity = if (draft.rentOnly) draft.currentElectricity else draft.previousElectricity
    return Bill(
        buildingId = room.buildingId,
        roomId = room.id,
        roomNumber = room.number,
        month = draft.month,
        createdDate = YearMonth.parse(draft.month).atDay(1).toString(),
        previousWater = previousWater.wholeText(),
        currentWater = draft.currentWater.wholeText(),
        waterRate = (room.customWaterRate ?: settings.defaultWaterRate).normalizedDecimal(),
        waterAmount = value.waterAmount.wholeText(),
        previousElectricity = previousElectricity.wholeText(),
        currentElectricity = draft.currentElectricity.wholeText(),
        electricityRate = (room.customElectricityRate ?: settings.defaultElectricityRate).normalizedDecimal(),
        electricityAmount = value.electricityAmount.wholeText(),
        rent = room.rent.toDecimal().wholeText(),
        total = value.total.wholeText(),
        rentOnly = draft.rentOnly,
        waterUsage = value.waterUsage.wholeText(),
        electricityUsage = value.electricityUsage.wholeText(),
        customCharges = draft.customCharges.map {
            CustomCharge(it.name.trim(), it.amount.toDecimal().wholeText())
        }
    )
}

const val MERGED_RENT_CHARGE_PREFIX = "补收房租·"

fun missingBillMonths(previousBillMonth: String?, targetBillMonth: String): List<YearMonth> {
    val previous = previousBillMonth?.let { runCatching { YearMonth.parse(it) }.getOrNull() }
        ?: return emptyList()
    val target = runCatching { YearMonth.parse(targetBillMonth) }.getOrNull() ?: return emptyList()
    if (!previous.isBefore(target.minusMonths(1))) return emptyList()
    return generateSequence(previous.plusMonths(1)) { it.plusMonths(1) }
        .takeWhile { it.isBefore(target) }
        .toList()
}

fun BillDraft.withMergedRent(roomRent: String, months: List<YearMonth>): BillDraft {
    val manualCharges = customCharges.filterNot { it.name.startsWith(MERGED_RENT_CHARGE_PREFIX) }
    val mergedCharges = months.map { month ->
        CustomCharge(
            name = "$MERGED_RENT_CHARGE_PREFIX${month.year}年${month.monthValue}月",
            amount = roomRent
        )
    }
    return copy(customCharges = manualCharges + mergedCharges)
}

private fun meterUsage(
    previous: BigDecimal,
    current: BigDecimal,
    meterMaxText: String?,
    overrideText: String?,
    label: String
): BigDecimal {
    overrideText?.takeIf { it.isNotBlank() }?.let {
        val override = it.toDecimal()
        require(override >= BigDecimal.ZERO) { "${label}换表用量不能为负数" }
        return override
    }
    if (current >= previous) return current - previous
    val meterMax = requireNotNull(meterMaxText?.takeIf { it.isNotBlank() }?.toDecimal()) {
        "${label}读数变小，请设置归零上限或填写换表实际用量"
    }
    require(meterMax > previous && current >= BigDecimal.ZERO) { "${label}归零上限设置无效" }
    return meterMax - previous + current
}

fun Bill.resolvedWaterUsage(): String =
    waterUsage.takeIf { it.isNotBlank() } ?: fallbackUsage(currentWater, previousWater)

fun Bill.resolvedElectricityUsage(): String =
    electricityUsage.takeIf { it.isNotBlank() } ?: fallbackUsage(currentElectricity, previousElectricity)

private fun fallbackUsage(current: String, previous: String): String =
    (current.toDecimal() - previous.toDecimal()).wholeText()

fun String.toDecimal(): BigDecimal = trim().ifEmpty { "0" }.toBigDecimal()
fun String.normalizedDecimal(): String = toDecimal().stripTrailingZeros().toPlainString()
fun BigDecimal.whole(): BigDecimal = setScale(0, RoundingMode.HALF_UP)
fun BigDecimal.wholeText(): String = whole().toPlainString()
fun String.wholeText(): String = toDecimal().wholeText()
