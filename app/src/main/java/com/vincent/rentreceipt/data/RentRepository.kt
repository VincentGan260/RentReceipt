package com.vincent.rentreceipt.data

import android.content.Context
import com.vincent.rentreceipt.model.AppData
import com.vincent.rentreceipt.model.Bill
import com.vincent.rentreceipt.model.BillDraft
import com.vincent.rentreceipt.model.Building
import com.vincent.rentreceipt.model.CustomCharge
import com.vincent.rentreceipt.model.DEFAULT_BUILDING_ID
import com.vincent.rentreceipt.model.DepositStatus
import com.vincent.rentreceipt.model.PricingSettings
import com.vincent.rentreceipt.model.ReceiptTemplate
import com.vincent.rentreceipt.model.ReceiptTextElement
import com.vincent.rentreceipt.model.roomNumberComparator
import com.vincent.rentreceipt.model.Room
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.time.YearMonth

class RentRepository(context: Context) {
    private val preferences = context.getSharedPreferences("rent_receipt_data", Context.MODE_PRIVATE)
    private val _data = MutableStateFlow(loadWithRentMonthMigration())
    val data: StateFlow<AppData> = _data

    fun saveBuilding(building: Building) {
        val buildings = _data.value.buildings.toMutableList()
        val index = buildings.indexOfFirst { it.id == building.id }
        if (index >= 0) buildings[index] = building else buildings += building
        update(_data.value.copy(buildings = buildings))
    }

    fun saveBuildingSettings(buildingId: String, settings: PricingSettings) {
        val building = _data.value.buildings.firstOrNull { it.id == buildingId } ?: return
        saveBuilding(building.copy(settings = settings))
    }

    fun saveGlobalReceiptTemplate(template: ReceiptTemplate) =
        update(_data.value.copy(receiptTemplate = template))

    fun saveRoom(room: Room) {
        val rooms = _data.value.rooms.toMutableList()
        val index = rooms.indexOfFirst { it.id == room.id }
        if (index >= 0) rooms[index] = room else rooms += room
        update(_data.value.copy(rooms = rooms.sortedWith { left, right -> roomNumberComparator.compare(left.number, right.number) }))
    }

    fun saveRooms(imported: List<Room>) {
        val rooms = _data.value.rooms.associateBy { it.id }.toMutableMap()
        imported.forEach { room ->
            val existing = _data.value.rooms.firstOrNull {
                it.buildingId == room.buildingId && it.number == room.number
            }
            rooms[existing?.id ?: room.id] = if (existing == null) room else room.copy(
                id = existing.id,
                customWaterRate = existing.customWaterRate,
                customElectricityRate = existing.customElectricityRate
            )
        }
        update(_data.value.copy(rooms = rooms.values.sortedWith { left, right -> roomNumberComparator.compare(left.number, right.number) }))
    }

    fun deleteRoom(roomId: String) {
        update(_data.value.copy(rooms = _data.value.rooms.filterNot { it.id == roomId }))
    }

    fun saveBill(bill: Bill) {
        val bills = _data.value.bills.toMutableList()
        val index = bills.indexOfFirst { it.roomId == bill.roomId && it.month == bill.month }
        if (index >= 0) bills[index] = bill else bills += bill
        update(_data.value.copy(bills = bills.sortedByDescending { it.month }))
    }

    fun markMonthPaid(buildingId: String, month: String, paidDate: String) {
        val bills = _data.value.bills.map { bill ->
            if (bill.buildingId == buildingId && bill.month == month && !bill.paid) {
                bill.copy(paid = true, paidDate = paidDate)
            } else bill
        }
        update(_data.value.copy(bills = bills))
    }

    fun saveBills(imported: List<Bill>) {
        val bills = _data.value.bills.toMutableList()
        imported.forEach { bill ->
            val index = bills.indexOfFirst { it.roomId == bill.roomId && it.month == bill.month }
            if (index >= 0) {
                val existing = bills[index]
                bills[index] = bill.copy(
                    id = existing.id,
                    paid = existing.paid,
                    paidDate = existing.paidDate
                )
            } else bills += bill
        }
        update(_data.value.copy(bills = bills.sortedByDescending { it.month }))
    }

    fun loadBillDraft(buildingId: String, roomId: String, month: String): BillDraft? = runCatching {
        val value = preferences.getString(draftKey(buildingId, roomId, month), null) ?: return null
        JSONObject(value).let { json ->
            BillDraft(
                month = month,
                previousWater = json.optString("previousWater"),
                currentWater = json.optString("currentWater"),
                previousElectricity = json.optString("previousElectricity"),
                currentElectricity = json.optString("currentElectricity"),
                rentOnly = json.optBoolean("rentOnly", false),
                waterUsageOverride = json.optString("waterUsageOverride").takeIf(String::isNotBlank),
                electricityUsageOverride = json.optString("electricityUsageOverride").takeIf(String::isNotBlank),
                customCharges = json.optJSONArray("customCharges")?.toCustomCharges().orEmpty()
            )
        }
    }.getOrNull()

    fun saveBillDraft(buildingId: String, roomId: String, draft: BillDraft) {
        val value = JSONObject().apply {
            put("previousWater", draft.previousWater)
            put("currentWater", draft.currentWater)
            put("previousElectricity", draft.previousElectricity)
            put("currentElectricity", draft.currentElectricity)
            put("rentOnly", draft.rentOnly)
            put("waterUsageOverride", draft.waterUsageOverride.orEmpty())
            put("electricityUsageOverride", draft.electricityUsageOverride.orEmpty())
            put("customCharges", draft.customCharges.toJson())
        }
        preferences.edit().putString(draftKey(buildingId, roomId, draft.month), value.toString()).apply()
    }

    fun replaceAll(data: AppData) = update(
        data.copy(
            buildings = data.buildings.ifEmpty { listOf(Building(DEFAULT_BUILDING_ID, "默认楼栋")) },
            rooms = data.rooms.sortedWith { left, right ->
                val buildingOrder = left.buildingId.compareTo(right.buildingId)
                if (buildingOrder != 0) buildingOrder else roomNumberComparator.compare(left.number, right.number)
            },
            bills = data.bills.sortedWith(compareByDescending<Bill> { it.month }.thenBy { it.buildingId })
        )
    )

    private fun update(data: AppData) {
        _data.value = data
        preferences.edit().putString("data", data.toJson().toString()).apply()
    }

    private fun load(): AppData = runCatching {
        preferences.getString("data", null)?.let { appDataFromJson(JSONObject(it)) }
    }.getOrNull() ?: AppData()

    private fun loadWithRentMonthMigration(): AppData {
        val loaded = load()
        if (preferences.getBoolean(RENT_MONTH_MIGRATED, false)) return loaded

        val migrated = loaded.copy(
            bills = loaded.bills.map { bill ->
                bill.copy(month = YearMonth.parse(bill.month).plusMonths(1).toString())
            }.sortedByDescending { it.month }
        )
        val draftValues = preferences.all
            .filterKeys { it.startsWith(BILL_DRAFT_PREFIX) }
            .mapNotNull { (key, value) -> (value as? String)?.let { key to it } }
        val editor = preferences.edit()
            .putString("data", migrated.toJson().toString())
            .putBoolean(RENT_MONTH_MIGRATED, true)
        draftValues.forEach { (key, _) -> editor.remove(key) }
        draftValues.forEach { (oldKey, value) ->
            val oldMonth = oldKey.substringAfterLast(':')
            val newMonth = runCatching { YearMonth.parse(oldMonth).plusMonths(1).toString() }.getOrNull()
            if (newMonth != null) editor.putString(oldKey.removeSuffix(oldMonth) + newMonth, value)
            else editor.putString(oldKey, value)
        }
        editor.apply()
        return migrated
    }

    private fun draftKey(buildingId: String, roomId: String, month: String) =
        "$BILL_DRAFT_PREFIX$buildingId:$roomId:$month"

    private companion object {
        const val BILL_DRAFT_PREFIX = "bill_draft:"
        const val RENT_MONTH_MIGRATED = "rent_month_semantics_v2"
    }
}

private fun AppData.toJson() = JSONObject().apply {
    put("buildings", JSONArray().apply { buildings.forEach { put(it.toJson()) } })
    put("rooms", JSONArray().apply { rooms.forEach { put(it.toJson()) } })
    put("bills", JSONArray().apply { bills.forEach { put(it.toJson()) } })
    put("receiptTemplate", receiptTemplate.toJson())
}

private fun Building.toJson() = JSONObject().apply {
    put("id", id); put("name", name)
    put("water", settings.defaultWaterRate); put("electricity", settings.defaultElectricityRate)
    put("waterMeterMax", settings.defaultWaterMeterMax ?: JSONObject.NULL)
    put("electricityMeterMax", settings.defaultElectricityMeterMax ?: JSONObject.NULL)
    put("receiptTemplate", receiptTemplate?.toJson() ?: JSONObject.NULL)
}

private fun ReceiptTemplate.toJson() = JSONArray().apply {
    elements.forEach { element ->
        put(JSONObject().apply {
            put("id", element.id); put("content", element.content)
            put("x", element.x.toDouble()); put("y", element.y.toDouble())
            put("fontSize", element.fontSize.toDouble()); put("centered", element.centered)
            put("color", element.color)
        })
    }
}

private fun Room.toJson() = JSONObject().apply {
    put("id", id); put("buildingId", buildingId); put("number", number); put("rent", rent)
    put("water", customWaterRate ?: JSONObject.NULL)
    put("electricity", customElectricityRate ?: JSONObject.NULL)
    put("occupied", occupied); put("depositAmount", depositAmount)
    put("depositStatus", depositStatus.name)
    put("depositCollectedDate", depositCollectedDate ?: JSONObject.NULL)
    put("depositRefundedDate", depositRefundedDate ?: JSONObject.NULL)
    put("waterMeterMax", customWaterMeterMax ?: JSONObject.NULL)
    put("electricityMeterMax", customElectricityMeterMax ?: JSONObject.NULL)
}

private fun Bill.toJson() = JSONObject().apply {
    put("id", id); put("buildingId", buildingId); put("roomId", roomId); put("roomNumber", roomNumber); put("month", month)
    put("createdDate", createdDate); put("previousWater", previousWater); put("currentWater", currentWater)
    put("waterRate", waterRate); put("waterAmount", waterAmount)
    put("previousElectricity", previousElectricity); put("currentElectricity", currentElectricity)
    put("electricityRate", electricityRate); put("electricityAmount", electricityAmount)
    put("rent", rent); put("total", total)
    put("rentOnly", rentOnly)
    put("paid", paid); put("paidDate", paidDate ?: JSONObject.NULL)
    put("waterUsage", waterUsage); put("electricityUsage", electricityUsage)
    put("customCharges", customCharges.toJson())
}

private fun List<CustomCharge>.toJson() = JSONArray().apply {
    forEach { charge ->
        put(JSONObject().apply {
            put("name", charge.name)
            put("amount", charge.amount)
        })
    }
}

private fun JSONArray.toCustomCharges() = List(length()) { index ->
    getJSONObject(index).let { CustomCharge(it.optString("name"), it.optString("amount")) }
}

private fun appDataFromJson(root: JSONObject): AppData {
    val settingsJson = root.optJSONObject("settings") ?: JSONObject()
    val buildingsJson = root.optJSONArray("buildings")
    val roomsJson = root.optJSONArray("rooms") ?: JSONArray()
    val billsJson = root.optJSONArray("bills") ?: JSONArray()
    val buildings = if (buildingsJson == null || buildingsJson.length() == 0) {
        listOf(
            Building(
                DEFAULT_BUILDING_ID,
                "默认楼栋",
                PricingSettings(
                    settingsJson.optString("water", "5.00"),
                    settingsJson.optString("electricity", "1.30"),
                    null,
                    "10000"
                )
            )
        )
    } else {
        List(buildingsJson.length()) { index -> buildingsJson.getJSONObject(index).toBuilding() }
    }
    val fallbackBuildingId = buildings.first().id
    return AppData(
        buildings = buildings,
        rooms = List(roomsJson.length()) { index -> roomsJson.getJSONObject(index).toRoom(fallbackBuildingId) },
        bills = List(billsJson.length()) { index -> billsJson.getJSONObject(index).toBill(fallbackBuildingId) },
        receiptTemplate = root.optJSONArray("receiptTemplate")?.toReceiptTemplate() ?: ReceiptTemplate()
    )
}

private fun JSONObject.nullableString(key: String): String? =
    if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() }

private fun JSONObject.toBuilding() = Building(
    id = getString("id"),
    name = getString("name"),
    settings = PricingSettings(
        optString("water", "5.00"),
        optString("electricity", "1.30"),
        nullableString("waterMeterMax"),
        nullableString("electricityMeterMax") ?: "10000"
    ),
    receiptTemplate = optJSONArray("receiptTemplate")?.toReceiptTemplate()
)

private fun JSONArray.toReceiptTemplate() = ReceiptTemplate(
    List(length()) { index ->
        val value = getJSONObject(index)
        ReceiptTextElement(
            id = value.getString("id"), content = value.getString("content"),
            x = value.getDouble("x").toFloat(), y = value.getDouble("y").toFloat(),
            fontSize = value.getDouble("fontSize").toFloat(),
            centered = value.optBoolean("centered"), color = value.optString("color", "body")
        )
    }
)

private fun JSONObject.toRoom(fallbackBuildingId: String) = Room(
    id = getString("id"), number = getString("number"), rent = getString("rent"),
    customWaterRate = nullableString("water"), customElectricityRate = nullableString("electricity"),
    buildingId = optString("buildingId", fallbackBuildingId),
    occupied = optBoolean("occupied", false),
    depositAmount = optString("depositAmount", "0"),
    depositStatus = runCatching {
        DepositStatus.valueOf(optString("depositStatus", DepositStatus.NOT_COLLECTED.name))
    }.getOrDefault(DepositStatus.NOT_COLLECTED),
    depositCollectedDate = nullableString("depositCollectedDate"),
    depositRefundedDate = nullableString("depositRefundedDate"),
    customWaterMeterMax = nullableString("waterMeterMax"),
    customElectricityMeterMax = nullableString("electricityMeterMax")
)

private fun JSONObject.toBill(fallbackBuildingId: String) = Bill(
    id = getString("id"), buildingId = optString("buildingId", fallbackBuildingId),
    roomId = getString("roomId"), roomNumber = getString("roomNumber"),
    month = getString("month"), createdDate = getString("createdDate"),
    previousWater = getString("previousWater"), currentWater = getString("currentWater"),
    waterRate = getString("waterRate"), waterAmount = getString("waterAmount"),
    previousElectricity = getString("previousElectricity"), currentElectricity = getString("currentElectricity"),
    electricityRate = getString("electricityRate"), electricityAmount = getString("electricityAmount"),
    rent = getString("rent"), total = getString("total"),
    rentOnly = optBoolean("rentOnly", false),
    paid = optBoolean("paid", false), paidDate = nullableString("paidDate"),
    waterUsage = optString("waterUsage", ""),
    electricityUsage = optString("electricityUsage", ""),
    customCharges = optJSONArray("customCharges")?.toCustomCharges().orEmpty()
)
