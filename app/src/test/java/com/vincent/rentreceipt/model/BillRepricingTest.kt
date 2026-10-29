package com.vincent.rentreceipt.model

import org.junit.Assert.*
import org.junit.Test

class BillRepricingTest {
    private val room = Room(id = "room", number = "101", rent = "500")
    private val settings = PricingSettings(defaultWaterRate = "5", defaultElectricityRate = "1")
    private fun bill(charges: List<CustomCharge> = emptyList()) = createBill(room, settings, BillDraft(
        month = "2026-11", previousWater = "100", currentWater = "103",
        previousElectricity = "200", currentElectricity = "210", customCharges = charges
    ))

    @Test fun repricesFeesAndPreservesIdentityPaymentAndUsage() {
        val original = bill().copy(paid = true, paidDate = "2026-10-26", createdDate = "2026-10-20")
        val updated = original.reprice(room, settings.copy(defaultWaterRate = "6", defaultManagementRate = "2"))
        assertEquals("548", updated.total)
        assertEquals(original.id, updated.id)
        assertEquals(original.createdDate, updated.createdDate)
        assertEquals(original.month, updated.month)
        assertEquals(original.previousWater, updated.previousWater)
        assertEquals(original.waterUsage, updated.waterUsage)
        assertTrue(updated.paid)
        assertEquals(original.paidDate, updated.paidDate)
        assertEquals("525", original.total)
    }

    @Test fun preservesMeterReplacementUsage() {
        val original = createBill(room, settings, BillDraft(
            month = "2026-11", previousWater = "900", currentWater = "10",
            previousElectricity = "200", currentElectricity = "210", waterUsageOverride = "7"
        ))
        val updated = original.reprice(room, settings.copy(defaultWaterRate = "8"))
        assertEquals("7", updated.waterUsage)
        assertEquals("56", updated.waterAmount)
    }

    @Test fun changesRecurringFeesAndKeepsManualAndMergedRentCharges() {
        val oldRoom = room.copy(recurringCharges = listOf(CustomCharge("网费", "10")))
        val original = bill(listOf(CustomCharge("网费", "10"), CustomCharge("维修", "20"),
            CustomCharge("${MERGED_RENT_CHARGE_PREFIX}2026年10月", "500")))
        val updated = original.reprice(oldRoom.copy(recurringCharges = listOf(CustomCharge("网费", "15"))), settings, oldRoom)
        assertEquals("1060", updated.total)
        assertEquals(1, updated.customCharges.count { it.name == "网费" })
        assertTrue(updated.customCharges.contains(CustomCharge("维修", "20")))
        assertTrue(updated.customCharges.any { it.name.startsWith(MERGED_RENT_CHARGE_PREFIX) && it.amount == "500" })
    }

    @Test fun independentRoomFeesIgnoreDefaultPriceChangesAndFormatting() {
        val custom = room.copy(customWaterRate = "6", customElectricityRate = "2", customManagementRate = "1")
        assertEquals(custom.billingFees(settings), custom.billingFees(settings.copy(
            defaultWaterRate = "99", defaultElectricityRate = "88", defaultManagementRate = "77")))
        assertEquals(room.billingFees(settings), room.copy(rent = "500.00").billingFees(settings.copy(defaultWaterRate = "5.00")))
    }

    @Test fun rentOnlyBillStillExcludesWaterElectricityAndManagement() {
        val original = createBill(room, settings, BillDraft(month = "2026-11", currentWater = "100",
            currentElectricity = "200", rentOnly = true))
        val updated = original.reprice(room.copy(rent = "600"), settings.copy(defaultManagementRate = "10"))
        assertEquals("600", updated.total)
        assertEquals("0", updated.waterAmount)
        assertEquals("0", updated.electricityAmount)
        assertEquals("0", updated.managementAmount)
    }
}
