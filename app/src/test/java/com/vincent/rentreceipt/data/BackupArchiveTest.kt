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

class BackupArchiveTest {
    @Test
    fun roundTripsSettingsRoomsAndBills() {
        val globalTemplate = ReceiptTemplate(listOf(ReceiptTextElement("title", "全局标题", 100f, 200f, 60f)))
        val buildingTemplate = ReceiptTemplate(listOf(ReceiptTextElement("title", "东楼标题", 110f, 210f, 62f)))
        val building = Building(
            id = "building-1", name = "东楼", settings = PricingSettings("5.125", "1.3"),
            receiptTemplate = buildingTemplate
        )
        val room = Room(
            id = "room-1", number = "604,东", rent = "650",
            customWaterRate = "5.125", buildingId = building.id, occupied = true,
            depositAmount = "1000", depositStatus = DepositStatus.COLLECTED,
            depositCollectedDate = "2026-01-01"
        )
        val bill = Bill(
            id = "bill-1", buildingId = building.id, roomId = room.id, roomNumber = room.number, month = "2026-08",
            createdDate = "2026-08-01", previousWater = "513", currentWater = "515",
            waterRate = "5.125", waterAmount = "10", previousElectricity = "3123",
            currentElectricity = "3257", electricityRate = "1.3", electricityAmount = "174",
            rent = "650", total = "864", paid = true, paidDate = "2026-08-02",
            customCharges = listOf(CustomCharge("门卡费", "20"), CustomCharge("维修费", "10"))
        )
        val original = AppData(listOf(building), listOf(room), listOf(bill), globalTemplate)
        val bytes = ByteArrayOutputStream().also { BackupArchive.export(original, it) }.toByteArray()
        assertEquals(original, BackupArchive.import(ByteArrayInputStream(bytes)))
    }
}
