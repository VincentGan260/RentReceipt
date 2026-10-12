package com.vincent.rentreceipt.data

import com.vincent.rentreceipt.model.CustomCharge
import com.vincent.rentreceipt.model.DepositStatus
import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class LegacyBackupCompatibilityTest {
    @Test
    fun restoresPopulatedBackupsFromEveryLegacyVersion() {
        for (version in 1..8) {
            val restored = BackupArchive.import(ByteArrayInputStream(legacyArchive(version)))
            val building = restored.buildings.single()
            val room = restored.rooms.single()
            val bill = restored.bills.single()
            assertEquals("version $version", "5.125", building.settings.defaultWaterRate)
            assertNull(building.settings.defaultManagementRate)
            assertEquals("604,东", room.number)
            assertEquals("650", room.rent)
            assertEquals("6.25", room.customWaterRate)
            assertEquals("1.5", room.customElectricityRate)
            assertEquals(building.id, room.buildingId)
            assertEquals(building.id, bill.buildingId)
            assertEquals(room.id, bill.roomId)
            assertEquals("10", bill.waterAmount)
            assertEquals("174", bill.electricityAmount)
            assertEquals(if (version >= 8) "864" else "834", bill.total)
            assertNull(bill.managementRate)
            assertEquals("0", bill.managementAmount)
            assertEquals(version >= 4, bill.paid)
            assertEquals(if (version >= 4) "2026-08-02" else null, bill.paidDate)
            assertEquals(version >= 4, room.occupied)
            assertEquals(if (version >= 4) DepositStatus.COLLECTED else DepositStatus.NOT_COLLECTED, room.depositStatus)
            assertEquals(if (version >= 6) "134" else "", bill.electricityUsage)
            assertEquals(version >= 7, bill.rentOnly)
            assertEquals(if (version >= 8) listOf(CustomCharge("门卡,补办", "30")) else emptyList<CustomCharge>(), bill.customCharges)
            if (version >= 3) {
                assertEquals("旧模板标题", restored.receiptTemplate.elements.single().content)
                assertEquals("楼栋标题", building.receiptTemplate!!.elements.single().content)
            }
            // Restored legacy data must survive a new-format export without changes.
            val output = ByteArrayOutputStream().also { BackupArchive.export(restored, it) }
            assertEquals(restored, BackupArchive.import(ByteArrayInputStream(output.toByteArray())))
        }
    }

    private fun legacyArchive(version: Int): ByteArray {
        val files = linkedMapOf<String, String>()
        files["manifest.csv"] = "format,version\nrent-receipt,$version\n"
        if (version == 1) {
            files["settings.csv"] = "key,value\ndefault_water_rate,5.125\ndefault_electricity_rate,1.3\n"
            files["rooms.csv"] = "id,number,rent,custom_water_rate,custom_electricity_rate\nroom-1,\"604,东\",650,6.25,1.5\n"
            files["bills.csv"] = "id,room_id,room_number,month,created_date,previous_water,current_water,water_rate,water_amount,previous_electricity,current_electricity,electricity_rate,electricity_amount,rent,total\nbill-1,room-1,\"604,东\",2026-08,2026-08-01,513,515,5.125,10,3123,3257,1.3,174,650,834\n"
        } else {
            val meterHeader = if (version >= 6) ",default_water_meter_max,default_electricity_meter_max" else ""
            val meterValues = if (version >= 6) ",,10000" else ""
            files["buildings.csv"] = "id,name,default_water_rate,default_electricity_rate$meterHeader\nbuilding-1,东楼,5.125,1.3$meterValues\n"
            var roomHeader = "id,building_id,number,rent,custom_water_rate,custom_electricity_rate"
            var roomRow = "room-1,building-1,\"604,东\",650,6.25,1.5"
            if (version >= 4) {
                roomHeader += ",occupied,deposit_amount,deposit_status,deposit_collected_date,deposit_refunded_date"
                roomRow += ",true,1000,COLLECTED,2026-01-01,"
            }
            if (version >= 6) {
                roomHeader += ",custom_water_meter_max,custom_electricity_meter_max"
                roomRow += ",,10000"
            }
            files["rooms.csv"] = "$roomHeader\n$roomRow\n"
            var billHeader = "id,building_id,room_id,room_number,month,created_date,previous_water,current_water,water_rate,water_amount,previous_electricity,current_electricity,electricity_rate,electricity_amount,rent,total"
            var billRow = "bill-1,building-1,room-1,\"604,东\",2026-08,2026-08-01,513,515,5.125,10,3123,3257,1.3,174,650," + if (version >= 8) "864" else "834"
            if (version >= 4) { billHeader += ",paid,paid_date"; billRow += ",true,2026-08-02" }
            if (version >= 6) { billHeader += ",water_usage,electricity_usage"; billRow += ",2,134" }
            if (version >= 7) { billHeader += ",rent_only"; billRow += ",true" }
            files["bills.csv"] = "$billHeader\n$billRow\n"
            if (version >= 3) files["receipt_templates.csv"] = "scope,building_id,id,content,x,y,font_size,centered,color\nglobal,,title,旧模板标题,100,200,60,true,body\nbuilding,building-1,title,楼栋标题,110,210,62,true,body\n"
            if (version >= 8) files["bill_charges.csv"] = "bill_id,item_index,name,amount\nbill-1,0,\"门卡,补办\",30\n"
        }
        return ByteArrayOutputStream().also { bytes ->
            ZipOutputStream(bytes).use { zip ->
                files.forEach { (name, content) ->
                    zip.putNextEntry(ZipEntry(name))
                    zip.write(("\uFEFF" + content.replace("\n", "\r\n")).toByteArray(Charsets.UTF_8))
                    zip.closeEntry()
                }
            }
        }.toByteArray()
    }
}
