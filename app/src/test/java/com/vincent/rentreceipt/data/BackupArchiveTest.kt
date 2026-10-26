package com.vincent.rentreceipt.data

import com.vincent.rentreceipt.model.AppData
import com.vincent.rentreceipt.model.Bill
import com.vincent.rentreceipt.model.Building
import com.vincent.rentreceipt.model.CustomCharge
import com.vincent.rentreceipt.model.DepositStatus
import com.vincent.rentreceipt.model.PricingSettings
import com.vincent.rentreceipt.model.Room
import com.vincent.rentreceipt.model.ReceiptTemplate
import com.vincent.rentreceipt.model.ReceiptTextElement
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

class BackupArchiveTest {
    @Test
    fun roundTripPreservesExplicitlyBlankElectricityMeterLimit() {
        val original = AppData(buildings = listOf(Building(
            id = "building-1", name = "东楼",
            settings = PricingSettings(defaultElectricityMeterMax = null)
        )))
        val bytes = ByteArrayOutputStream().also { BackupArchive.export(original, it) }.toByteArray()
        assertEquals(original, BackupArchive.import(ByteArrayInputStream(bytes)))
    }

    @Test
    fun roundTripsSettingsRoomsAndBills() {
        val globalTemplate = ReceiptTemplate(listOf(ReceiptTextElement("title", "全局标题", 100f, 200f, 60f)))
        val buildingTemplate = ReceiptTemplate(listOf(ReceiptTextElement("title", "东楼标题", 110f, 210f, 62f)))
        val building = Building(
            id = "building-1", name = "东楼", settings = PricingSettings("5.125", "1.3", defaultManagementRate = "0.25"),
            receiptTemplate = buildingTemplate
        )
        val room = Room(
            id = "room-1", number = "604,东", rent = "650",
            customWaterRate = "5.125", buildingId = building.id, occupied = true,
            depositAmount = "1000", depositStatus = DepositStatus.COLLECTED,
            depositCollectedDate = "2026-01-01", customManagementRate = "0.6",
            recurringCharges = listOf(CustomCharge("卫生费", "20"), CustomCharge("网络费", "30"))
        )
        val bill = Bill(
            id = "bill-1", buildingId = building.id, roomId = room.id, roomNumber = room.number, month = "2026-08",
            createdDate = "2026-08-01", previousWater = "513", currentWater = "515",
            waterRate = "5.125", waterAmount = "10", previousElectricity = "3123",
            currentElectricity = "3257", electricityRate = "1.3", electricityAmount = "174",
            rent = "650", total = "898", managementRate = "0.25", managementAmount = "34", paid = true, paidDate = "2026-08-02",
            customCharges = listOf(CustomCharge("门卡费", "20"), CustomCharge("维修费", "10"))
        )
        val original = AppData(listOf(building), listOf(room), listOf(bill), globalTemplate)
        val bytes = ByteArrayOutputStream().also { BackupArchive.export(original, it) }.toByteArray()
        assertEquals(original, BackupArchive.import(ByteArrayInputStream(bytes)))
    }
    @Test
    fun importsVersion8WithoutManagementFields() {
        val original = AppData()
        val current = ByteArrayOutputStream().also { BackupArchive.export(original, it) }.toByteArray()
        val legacy = ByteArrayOutputStream()
        ZipOutputStream(legacy).use { output ->
            ZipInputStream(ByteArrayInputStream(current)).use { input ->
                while (true) {
                    val entry = input.nextEntry ?: break
                    if (entry.name == "room_charges.csv") continue
                    val content = input.readBytes().toString(Charsets.UTF_8)
                    val converted = when (entry.name) {
                        "manifest.csv" -> content.replace("rent-receipt,10", "rent-receipt,8")
                        "buildings.csv", "rooms.csv" -> content.lineSequence().filter { it.isNotBlank() }
                            .joinToString("\n", postfix = "\n") { it.substringBeforeLast(',') }
                        "bills.csv" -> content.lineSequence().filter { it.isNotBlank() }
                            .joinToString("\n", postfix = "\n") { it.substringBeforeLast(',').substringBeforeLast(',') }
                        else -> content
                    }
                    output.putNextEntry(ZipEntry(entry.name))
                    output.write(converted.toByteArray(Charsets.UTF_8))
                    output.closeEntry()
                }
            }
        }
        assertEquals(original, BackupArchive.import(ByteArrayInputStream(legacy.toByteArray())))
    }
    @Test
    fun importsVersion9WithManagementButWithoutRoomCharges() {
        val room = Room(id = "room-1", number = "101", rent = "500")
        val settings = PricingSettings(defaultManagementRate = "0.6")
        val bill = com.vincent.rentreceipt.model.createBill(room, settings,
            com.vincent.rentreceipt.model.BillDraft(previousWater = "1", currentWater = "2", previousElectricity = "1", currentElectricity = "101"))
        val original = AppData(buildings = listOf(Building(id = room.buildingId, name = "测试楼栋", settings = settings)),
            rooms = listOf(room), bills = listOf(bill))
        val current = ByteArrayOutputStream().also { BackupArchive.export(original, it) }.toByteArray()
        val legacy = ByteArrayOutputStream()
        ZipOutputStream(legacy).use { output ->
            ZipInputStream(ByteArrayInputStream(current)).use { input ->
                while (true) {
                    val entry = input.nextEntry ?: break
                    if (entry.name == "room_charges.csv") continue
                    val content = input.readBytes().toString(Charsets.UTF_8)
                    val converted = when (entry.name) {
                        "manifest.csv" -> content.replace("rent-receipt,10", "rent-receipt,9")
                        "rooms.csv" -> content.lineSequence().filter { it.isNotBlank() }
                            .joinToString("\n", postfix = "\n") { it.substringBeforeLast(',') }
                        else -> content
                    }
                    output.putNextEntry(ZipEntry(entry.name)); output.write(converted.toByteArray(Charsets.UTF_8)); output.closeEntry()
                }
            }
        }
        assertEquals(original, BackupArchive.import(ByteArrayInputStream(legacy.toByteArray())))
    }
}
