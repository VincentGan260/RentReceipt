package com.vincent.rentreceipt.data

import com.vincent.rentreceipt.model.AppData
import com.vincent.rentreceipt.model.Bill
import com.vincent.rentreceipt.model.Building
import com.vincent.rentreceipt.model.CustomCharge
import com.vincent.rentreceipt.model.DEFAULT_BUILDING_ID
import com.vincent.rentreceipt.model.DepositStatus
import com.vincent.rentreceipt.model.PricingSettings
import com.vincent.rentreceipt.model.ReceiptTemplate
import com.vincent.rentreceipt.model.ReceiptTextElement
import com.vincent.rentreceipt.model.Room
import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.StandardCharsets
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

object BackupArchive {
    private const val VERSION = "8"
    private const val MAX_ENTRY_BYTES = 20 * 1024 * 1024

    fun export(data: AppData, output: OutputStream) {
        ZipOutputStream(output.buffered()).use { zip ->
            zip.writeCsv("manifest.csv", listOf(listOf("format", "version"), listOf("rent-receipt", VERSION)))
            zip.writeCsv("buildings.csv", buildList {
                add(listOf(
                    "id", "name", "default_water_rate", "default_electricity_rate",
                    "default_water_meter_max", "default_electricity_meter_max"
                ))
                data.buildings.forEach {
                    add(listOf(
                        it.id, it.name, it.settings.defaultWaterRate, it.settings.defaultElectricityRate,
                        it.settings.defaultWaterMeterMax.orEmpty(),
                        it.settings.defaultElectricityMeterMax.orEmpty()
                    ))
                }
            })
            zip.writeCsv("receipt_templates.csv", buildList {
                add(listOf("scope", "building_id", "id", "content", "x", "y", "font_size", "centered", "color"))
                data.receiptTemplate.elements.forEach { add(it.toBackupRow("global", "")) }
                data.buildings.forEach { building ->
                    building.receiptTemplate?.elements?.forEach {
                        add(it.toBackupRow("building", building.id))
                    }
                }
            })
            zip.writeCsv(
                "rooms.csv",
                buildList {
                    add(
                        listOf(
                            "id", "building_id", "number", "rent", "custom_water_rate",
                            "custom_electricity_rate", "occupied", "deposit_amount",
                            "deposit_status", "deposit_collected_date", "deposit_refunded_date",
                            "custom_water_meter_max", "custom_electricity_meter_max"
                        )
                    )
                    data.rooms.forEach { room ->
                        add(
                            listOf(
                                room.id, room.buildingId, room.number, room.rent,
                                room.customWaterRate.orEmpty(), room.customElectricityRate.orEmpty(),
                                room.occupied.toString(), room.depositAmount, room.depositStatus.name,
                                room.depositCollectedDate.orEmpty(), room.depositRefundedDate.orEmpty(),
                                room.customWaterMeterMax.orEmpty(), room.customElectricityMeterMax.orEmpty()
                            )
                        )
                    }
                }
            )
            zip.writeCsv(
                "bills.csv",
                buildList {
                    add(
                        listOf(
                            "id", "building_id", "room_id", "room_number", "month", "created_date",
                            "previous_water", "current_water", "water_rate", "water_amount",
                            "previous_electricity", "current_electricity", "electricity_rate",
                            "electricity_amount", "rent", "total", "paid", "paid_date",
                            "water_usage", "electricity_usage", "rent_only"
                        )
                    )
                    data.bills.forEach { bill ->
                        add(
                            listOf(
                                bill.id, bill.buildingId, bill.roomId, bill.roomNumber, bill.month, bill.createdDate,
                                bill.previousWater, bill.currentWater, bill.waterRate, bill.waterAmount,
                                bill.previousElectricity, bill.currentElectricity, bill.electricityRate,
                                bill.electricityAmount, bill.rent, bill.total,
                                bill.paid.toString(), bill.paidDate.orEmpty(),
                                bill.waterUsage, bill.electricityUsage, bill.rentOnly.toString()
                            )
                        )
                    }
                }
            )
            zip.writeCsv("bill_charges.csv", buildList {
                add(listOf("bill_id", "item_index", "name", "amount"))
                data.bills.forEach { bill ->
                    bill.customCharges.forEachIndexed { index, charge ->
                        add(listOf(bill.id, index.toString(), charge.name, charge.amount))
                    }
                }
            })
        }
    }

    fun import(input: InputStream): AppData {
        val entries = mutableMapOf<String, List<List<String>>>()
        ZipInputStream(input.buffered()).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                if (!entry.isDirectory && entry.name in setOf(
                        "manifest.csv", "settings.csv", "buildings.csv",
                        "receipt_templates.csv", "rooms.csv", "bills.csv", "bill_charges.csv"
                    )
                ) {
                    val bytes = zip.readLimitedBytes()
                    val text = bytes.toString(StandardCharsets.UTF_8).removePrefix("\uFEFF")
                    entries[entry.name] = parseCsv(text)
                }
                zip.closeEntry()
            }
        }
        val manifest = entries.requireTable("manifest.csv", listOf("format", "version"))
        val version = manifest.getOrNull(1)?.takeIf { it.firstOrNull() == "rent-receipt" }?.getOrNull(1)
            ?: error("备份格式不受支持")
        require(version in setOf("1", "2", "3", "4", "5", "6", "7", VERSION)) { "备份版本不受支持" }
        return when (version) {
            "1" -> importVersion1(entries)
            "2" -> importVersion2(entries, false, false, false, false, false)
            "3" -> importVersion2(entries, true, false, false, false, false)
            "4", "5" -> importVersion2(entries, true, true, false, false, false)
            "6" -> importVersion2(entries, true, true, true, false, false)
            "7" -> importVersion2(entries, true, true, true, true, false)
            else -> importVersion2(entries, true, true, true, true, true)
        }
    }

    private fun importVersion1(entries: Map<String, List<List<String>>>): AppData {
        val settingsRows = entries.requireTable("settings.csv", listOf("key", "value")).drop(1)
        val settings = settingsRows.associate { row -> row.required(0, "设置名称") to row.required(1, "设置值") }
        val pricing = PricingSettings(
            defaultWaterRate = settings["default_water_rate"] ?: error("备份缺少默认水价"),
            defaultElectricityRate = settings["default_electricity_rate"] ?: error("备份缺少默认电价")
        )
        pricing.defaultWaterRate.toBigDecimalOrNull() ?: error("默认水价格式错误")
        pricing.defaultElectricityRate.toBigDecimalOrNull() ?: error("默认电价格式错误")

        val building = Building(DEFAULT_BUILDING_ID, "默认楼栋", pricing)
        val rooms = entries.requireTable(
            "rooms.csv",
            listOf("id", "number", "rent", "custom_water_rate", "custom_electricity_rate")
        ).drop(1).filter { it.any(String::isNotBlank) }.map { row ->
            Room(
                id = row.required(0, "房间 ID"),
                number = row.required(1, "房间号"),
                rent = row.required(2, "租金").also { it.toBigDecimalOrNull() ?: error("房间租金格式错误") },
                customWaterRate = row.getOrNull(3)?.takeIf(String::isNotBlank)?.also {
                    it.toBigDecimalOrNull() ?: error("房间自定义水价格式错误")
                },
                customElectricityRate = row.getOrNull(4)?.takeIf(String::isNotBlank)?.also {
                    it.toBigDecimalOrNull() ?: error("房间自定义电价格式错误")
                },
                buildingId = building.id
            )
        }
        require(rooms.map { it.id }.distinct().size == rooms.size) { "备份中存在重复房间 ID" }

        val bills = entries.requireTable(
            "bills.csv",
            listOf(
                "id", "room_id", "room_number", "month", "created_date",
                "previous_water", "current_water", "water_rate", "water_amount",
                "previous_electricity", "current_electricity", "electricity_rate",
                "electricity_amount", "rent", "total"
            )
        ).drop(1).filter { it.any(String::isNotBlank) }.map { row ->
            Bill(
                id = row.required(0, "账单 ID"), buildingId = building.id, roomId = row.required(1, "账单房间 ID"),
                roomNumber = row.required(2, "账单房间号"), month = row.required(3, "账单月份"),
                createdDate = row.required(4, "账单日期"), previousWater = row.required(5, "上月水表"),
                currentWater = row.required(6, "本月水表"), waterRate = row.required(7, "水价"),
                waterAmount = row.required(8, "水费"), previousElectricity = row.required(9, "上月电表"),
                currentElectricity = row.required(10, "本月电表"), electricityRate = row.required(11, "电价"),
                electricityAmount = row.required(12, "电费"), rent = row.required(13, "租金"),
                total = row.required(14, "总价")
            ).also { bill ->
                listOf(
                    bill.previousWater, bill.currentWater, bill.waterRate, bill.waterAmount,
                    bill.previousElectricity, bill.currentElectricity, bill.electricityRate,
                    bill.electricityAmount, bill.rent, bill.total
                ).forEach { it.toBigDecimalOrNull() ?: error("账单数字格式错误") }
            }
        }
        require(bills.map { it.id }.distinct().size == bills.size) { "备份中存在重复账单 ID" }
        return AppData(listOf(building), rooms, bills)
    }

    private fun importVersion2(
        entries: Map<String, List<List<String>>>,
        hasTemplates: Boolean,
        hasRentalFields: Boolean,
        hasMeterFields: Boolean,
        hasRentOnly: Boolean,
        hasCustomCharges: Boolean
    ): AppData {
        var buildings = entries.requireTable(
            "buildings.csv",
            buildList {
                addAll(listOf("id", "name", "default_water_rate", "default_electricity_rate"))
                if (hasMeterFields) addAll(listOf("default_water_meter_max", "default_electricity_meter_max"))
            }
        ).drop(1).filter { it.any(String::isNotBlank) }.map { row ->
            Building(
                id = row.required(0, "楼栋 ID"),
                name = row.required(1, "楼栋名称"),
                settings = PricingSettings(
                    row.required(2, "默认水价").validatedDecimal("默认水价"),
                    row.required(3, "默认电价").validatedDecimal("默认电价"),
                    if (hasMeterFields) row.getOrNull(4)?.takeIf(String::isNotBlank)
                        ?.validatedDecimal("默认水表上限") else null,
                    if (hasMeterFields) row.getOrNull(5)?.takeIf(String::isNotBlank)
                        ?.validatedDecimal("默认电表上限") else "10000"
                )
            )
        }
        require(buildings.isNotEmpty()) { "备份中没有楼栋" }
        require(buildings.map { it.id }.distinct().size == buildings.size) { "备份中存在重复楼栋 ID" }
        val buildingIds = buildings.mapTo(mutableSetOf()) { it.id }

        val rooms = entries.requireTable(
            "rooms.csv",
            if (hasRentalFields) buildList {
                addAll(listOf(
                    "id", "building_id", "number", "rent", "custom_water_rate",
                    "custom_electricity_rate", "occupied", "deposit_amount",
                    "deposit_status", "deposit_collected_date", "deposit_refunded_date"
                ))
                if (hasMeterFields) addAll(listOf("custom_water_meter_max", "custom_electricity_meter_max"))
            } else listOf("id", "building_id", "number", "rent", "custom_water_rate", "custom_electricity_rate")
        ).drop(1).filter { it.any(String::isNotBlank) }.map { row ->
            Room(
                id = row.required(0, "房间 ID"),
                buildingId = row.required(1, "房间楼栋 ID").also { require(it in buildingIds) { "房间引用了不存在的楼栋" } },
                number = row.required(2, "房间号"),
                rent = row.required(3, "租金").validatedDecimal("房间租金"),
                customWaterRate = row.getOrNull(4)?.takeIf(String::isNotBlank)?.validatedDecimal("房间自定义水价"),
                customElectricityRate = row.getOrNull(5)?.takeIf(String::isNotBlank)?.validatedDecimal("房间自定义电价"),
                occupied = if (hasRentalFields) {
                    row.required(6, "出租状态").toBooleanStrictOrNull() ?: error("出租状态格式错误")
                } else false,
                depositAmount = if (hasRentalFields) row.required(7, "押金").validatedDecimal("押金") else "0",
                depositStatus = if (hasRentalFields) runCatching {
                    DepositStatus.valueOf(row.required(8, "押金状态"))
                }.getOrElse { error("押金状态格式错误") } else DepositStatus.NOT_COLLECTED,
                depositCollectedDate = if (hasRentalFields) row.getOrNull(9)?.takeIf(String::isNotBlank) else null,
                depositRefundedDate = if (hasRentalFields) row.getOrNull(10)?.takeIf(String::isNotBlank) else null,
                customWaterMeterMax = if (hasMeterFields) row.getOrNull(11)?.takeIf(String::isNotBlank)
                    ?.validatedDecimal("房间水表上限") else null,
                customElectricityMeterMax = if (hasMeterFields) row.getOrNull(12)?.takeIf(String::isNotBlank)
                    ?.validatedDecimal("房间电表上限") else null
            )
        }
        require(rooms.map { it.id }.distinct().size == rooms.size) { "备份中存在重复房间 ID" }

        var bills = entries.requireTable(
            "bills.csv",
            buildList {
                addAll(listOf(
                "id", "building_id", "room_id", "room_number", "month", "created_date",
                "previous_water", "current_water", "water_rate", "water_amount",
                "previous_electricity", "current_electricity", "electricity_rate",
                "electricity_amount", "rent", "total"
                ))
                if (hasRentalFields) addAll(listOf("paid", "paid_date"))
                if (hasMeterFields) addAll(listOf("water_usage", "electricity_usage"))
                if (hasRentOnly) add("rent_only")
            }
        ).drop(1).filter { it.any(String::isNotBlank) }.map { row ->
            Bill(
                id = row.required(0, "账单 ID"),
                buildingId = row.required(1, "账单楼栋 ID").also { require(it in buildingIds) { "账单引用了不存在的楼栋" } },
                roomId = row.required(2, "账单房间 ID"),
                roomNumber = row.required(3, "账单房间号"),
                month = row.required(4, "账单月份"),
                createdDate = row.required(5, "账单日期"),
                previousWater = row.required(6, "上月水表"),
                currentWater = row.required(7, "本月水表"),
                waterRate = row.required(8, "水价"),
                waterAmount = row.required(9, "水费"),
                previousElectricity = row.required(10, "上月电表"),
                currentElectricity = row.required(11, "本月电表"),
                electricityRate = row.required(12, "电价"),
                electricityAmount = row.required(13, "电费"),
                rent = row.required(14, "租金"),
                total = row.required(15, "总价"),
                paid = if (hasRentalFields) {
                    row.required(16, "收缴状态").toBooleanStrictOrNull() ?: error("收缴状态格式错误")
                } else false,
                paidDate = if (hasRentalFields) row.getOrNull(17)?.takeIf(String::isNotBlank) else null,
                waterUsage = if (hasMeterFields) row.getOrNull(18).orEmpty() else "",
                electricityUsage = if (hasMeterFields) row.getOrNull(19).orEmpty() else "",
                rentOnly = if (hasRentOnly) {
                    row.required(20, "仅收房租标记").toBooleanStrictOrNull() ?: error("仅收房租标记格式错误")
                } else false
            ).also { bill ->
                listOf(
                    bill.previousWater, bill.currentWater, bill.waterRate, bill.waterAmount,
                    bill.previousElectricity, bill.currentElectricity, bill.electricityRate,
                    bill.electricityAmount, bill.rent, bill.total,
                    bill.waterUsage.takeIf(String::isNotBlank),
                    bill.electricityUsage.takeIf(String::isNotBlank)
                ).filterNotNull().forEach { it.validatedDecimal("账单数字") }
            }
        }
        require(bills.map { it.id }.distinct().size == bills.size) { "备份中存在重复账单 ID" }
        if (hasCustomCharges) {
            val billIds = bills.mapTo(mutableSetOf()) { it.id }
            val chargesByBill = entries.requireTable(
                "bill_charges.csv",
                listOf("bill_id", "item_index", "name", "amount")
            ).drop(1).filter { it.any(String::isNotBlank) }.map { row ->
                val billId = row.required(0, "收费项账单 ID")
                require(billId in billIds) { "收费项引用了不存在的账单" }
                val index = row.required(1, "收费项顺序").toIntOrNull() ?: error("收费项顺序格式错误")
                require(index >= 0) { "收费项顺序不能为负数" }
                val name = row.required(2, "收费名称")
                val amount = row.required(3, "收费金额").validatedDecimal("收费金额")
                require(amount.toBigDecimal() >= java.math.BigDecimal.ZERO) { "收费金额不能为负数" }
                Triple(billId, index, CustomCharge(name, amount))
            }.groupBy({ it.first }, { it.second to it.third })
            bills = bills.map { bill ->
                bill.copy(customCharges = chargesByBill[bill.id].orEmpty().sortedBy { it.first }.map { it.second })
            }
        }
        var globalTemplate = ReceiptTemplate()
        if (hasTemplates) {
            val templateRows = entries.requireTable(
                "receipt_templates.csv",
                listOf("scope", "building_id", "id", "content", "x", "y", "font_size", "centered", "color")
            ).drop(1).filter { it.any(String::isNotBlank) }
            fun rowsToTemplate(rows: List<List<String>>) = ReceiptTemplate(rows.map { row ->
                ReceiptTextElement(
                    id = row.required(2, "模板元素 ID"),
                    content = row.getOrNull(3).orEmpty(),
                    x = row.required(4, "X").toFloatOrNull() ?: error("模板 X 格式错误"),
                    y = row.required(5, "Y").toFloatOrNull() ?: error("模板 Y 格式错误"),
                    fontSize = row.required(6, "字号").toFloatOrNull() ?: error("模板字号格式错误"),
                    centered = row.required(7, "居中").toBooleanStrictOrNull() ?: error("模板居中格式错误"),
                    color = row.required(8, "颜色")
                )
            })
            globalTemplate = rowsToTemplate(templateRows.filter { it.getOrNull(0) == "global" })
            require(globalTemplate.elements.isNotEmpty()) { "备份缺少全局收据模板" }
            buildings = buildings.map { building ->
                val rows = templateRows.filter {
                    it.getOrNull(0) == "building" && it.getOrNull(1) == building.id
                }
                if (rows.isEmpty()) building else building.copy(receiptTemplate = rowsToTemplate(rows))
            }
        }
        return AppData(buildings, rooms, bills, globalTemplate)
    }

    private fun ReceiptTextElement.toBackupRow(scope: String, buildingId: String) = listOf(
        scope, buildingId, id, content, x.toString(), y.toString(), fontSize.toString(),
        centered.toString(), color
    )

    private fun ZipOutputStream.writeCsv(name: String, rows: List<List<String>>) {
        putNextEntry(ZipEntry(name))
        write("\uFEFF".toByteArray(StandardCharsets.UTF_8))
        rows.forEach { row ->
            write(row.joinToString(",", postfix = "\r\n", transform = ::escapeCsv).toByteArray(StandardCharsets.UTF_8))
        }
        closeEntry()
    }

    private fun escapeCsv(value: String): String =
        if (value.any { it == ',' || it == '"' || it == '\n' || it == '\r' }) "\"${value.replace("\"", "\"\"")}\"" else value

    private fun parseCsv(text: String): List<List<String>> {
        val rows = mutableListOf<MutableList<String>>()
        var row = mutableListOf<String>()
        val field = StringBuilder()
        var quoted = false
        var index = 0
        while (index < text.length) {
            val char = text[index]
            when {
                quoted && char == '"' && index + 1 < text.length && text[index + 1] == '"' -> {
                    field.append('"'); index++
                }
                char == '"' -> quoted = !quoted
                !quoted && char == ',' -> { row += field.toString(); field.clear() }
                !quoted && (char == '\n' || char == '\r') -> {
                    row += field.toString(); field.clear()
                    if (row.any(String::isNotEmpty)) rows += row
                    row = mutableListOf()
                    if (char == '\r' && index + 1 < text.length && text[index + 1] == '\n') index++
                }
                else -> field.append(char)
            }
            index++
        }
        require(!quoted) { "CSV 引号未闭合" }
        if (field.isNotEmpty() || row.isNotEmpty()) {
            row += field.toString()
            if (row.any(String::isNotEmpty)) rows += row
        }
        return rows
    }

    private fun ZipInputStream.readLimitedBytes(): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var total = 0
        while (true) {
            val count = read(buffer)
            if (count < 0) break
            total += count
            require(total <= MAX_ENTRY_BYTES) { "备份文件过大" }
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    private fun Map<String, List<List<String>>>.requireTable(name: String, header: List<String>): List<List<String>> {
        val table = this[name] ?: error("备份缺少 $name")
        require(table.firstOrNull() == header) { "$name 表头不正确" }
        return table
    }

    private fun List<String>.required(index: Int, name: String): String =
        getOrNull(index)?.takeIf(String::isNotBlank) ?: error("$name 不能为空")

    private fun String.validatedDecimal(name: String): String =
        also { it.toBigDecimalOrNull() ?: error("$name 格式错误") }
}
