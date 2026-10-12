package com.vincent.rentreceipt.model

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.YearMonth

class BillCalculationTest {
    @Test
    fun usesDefaultRatesAndRoundsFeesToIntegers() {
        val room = Room(number = "604", rent = "650")
        val bill = createBill(
            room,
            PricingSettings(defaultWaterRate = "5", defaultElectricityRate = "1.30"),
            BillDraft(
                month = "2026-08",
                previousWater = "513",
                currentWater = "515",
                previousElectricity = "3123",
                currentElectricity = "3257"
            )
        )
        assertEquals("10", bill.waterAmount)
        assertEquals("174", bill.electricityAmount)
        assertEquals("834", bill.total)
        assertEquals("2026-08-01", bill.createdDate)
    }

    @Test
    fun roomRatesOverrideDefaults() {
        val room = Room(
            number = "701",
            rent = "500",
            customWaterRate = "6.00",
            customElectricityRate = "1.25"
        )
        val bill = createBill(
            room,
            PricingSettings(defaultWaterRate = "5", defaultElectricityRate = "1.30"),
            BillDraft(
                month = "2026-07",
                previousWater = "100",
                currentWater = "103",
                previousElectricity = "200",
                currentElectricity = "210"
            )
        )
        assertEquals("6", bill.waterRate)
        assertEquals("1.25", bill.electricityRate)
        assertEquals("531", bill.total)
    }

    @Test
    fun firstRentStoresMoveInReadingsAndChargesRentOnly() {
        val bill = createBill(
            Room(number = "801", rent = "700"),
            PricingSettings(),
            BillDraft(
                month = "2026-08",
                currentWater = "321",
                currentElectricity = "4567",
                rentOnly = true
            )
        )
        assertEquals("321", bill.previousWater)
        assertEquals("321", bill.currentWater)
        assertEquals("4567", bill.previousElectricity)
        assertEquals("4567", bill.currentElectricity)
        assertEquals("0", bill.waterAmount)
        assertEquals("0", bill.electricityAmount)
        assertEquals("700", bill.total)
        assertEquals(true, bill.rentOnly)
        assertEquals("2026-08-01", bill.createdDate)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsCurrentReadingBelowPreviousReading() {
        calculateBill(
            Room(number = "604", rent = "650"),
            PricingSettings(),
            BillDraft(previousWater = "515", currentWater = "513", previousElectricity = "1", currentElectricity = "2")
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsBlankReadings() {
        calculateBill(Room(number = "604", rent = "650"), PricingSettings(), BillDraft())
    }

    @Test
    fun handlesConfiguredMeterRollover() {
        val bill = createBill(
            Room(number = "501", rent = "450"),
            PricingSettings(defaultWaterRate = "5", defaultElectricityRate = "1.3", defaultElectricityMeterMax = "10000"),
            BillDraft(
                previousWater = "10",
                currentWater = "12",
                previousElectricity = "9887",
                currentElectricity = "137"
            )
        )
        assertEquals("250", bill.electricityUsage)
        assertEquals("325", bill.electricityAmount)
    }

    @Test
    fun detectsSkippedBillMonthAndMergesItsRent() {
        assertEquals(
            listOf(YearMonth.of(2026, 2)),
            missingBillMonths("2026-01", "2026-03")
        )
        val bill = createBill(
            Room(number = "501", rent = "700"),
            PricingSettings(defaultWaterRate = "5", defaultElectricityRate = "1"),
            BillDraft(
                month = "2026-03",
                previousWater = "100",
                currentWater = "110",
                previousElectricity = "1000",
                currentElectricity = "1050"
            ).withMergedRent("700", listOf(YearMonth.of(2026, 2)))
        )
        assertEquals("1500", bill.total)
        assertEquals("补收房租·2026年2月", bill.customCharges.single().name)
    }
    @Test
    fun managementFeeUsesElectricityUsageAndIsOptional() {
        val room = Room(number = "101", rent = "500")
        val draft = BillDraft(previousWater = "1", currentWater = "1",
            previousElectricity = "100", currentElectricity = "234")
        val settings = PricingSettings(defaultManagementRate = "0.25")
        val bill = createBill(room, settings, draft)
        assertEquals("34", bill.managementAmount)
        assertEquals("0.25", bill.managementRate)
        assertEquals("708", bill.total)
        assertEquals("0", createBill(room, PricingSettings(), draft).managementAmount)
        assertEquals("0", createBill(room, settings.copy(defaultManagementRate = ""), draft).managementAmount)
    }

    @Test
    fun managementFeeUsesRolloverAndReplacementUsage() {
        val room = Room(number = "101", rent = "500")
        val settings = PricingSettings(defaultManagementRate = "0.2")
        val draft = BillDraft(previousWater = "1", currentWater = "1",
            previousElectricity = "9900", currentElectricity = "100")
        assertEquals("40", createBill(room, settings, draft).managementAmount)
        assertEquals("10", createBill(room, settings, draft.copy(electricityUsageOverride = "50")).managementAmount)
        val moveIn = createBill(room, settings, draft.copy(rentOnly = true))
        assertEquals("0", moveIn.managementAmount)
        assertEquals("500", moveIn.total)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsNegativeManagementRate() {
        calculateBill(Room(number = "101", rent = "500"),
            PricingSettings(defaultManagementRate = "-0.2"),
            BillDraft(previousWater = "1", currentWater = "2", previousElectricity = "1", currentElectricity = "2"))
    }
    @Test
    fun roomManagementOverridesBuildingAndZeroDisablesIt() {
        val room = Room(number = "101", rent = "500", customManagementRate = "0.6")
        val settings = PricingSettings(defaultElectricityRate = "0.7", defaultManagementRate = "0.2")
        val draft = BillDraft(previousWater = "1", currentWater = "1", previousElectricity = "100", currentElectricity = "234")
        val bill = createBill(room, settings, draft)
        assertEquals("0.6", bill.managementRate)
        assertEquals("80", bill.managementAmount)
        assertEquals("674", bill.total)
        assertEquals("0", createBill(room.copy(customManagementRate = "0"), settings, draft).managementAmount)
    }

    @Test
    fun fixedRoomChargesApplyOnlyToNewBillsAndPreserveEdits() {
        val room = Room(number = "101", rent = "500", recurringCharges = listOf(CustomCharge("网络费", "30")))
        val draft = BillDraft(previousWater = "1", currentWater = "1", previousElectricity = "1", currentElectricity = "1",
            customCharges = room.chargesForBill(null, null))
        val bill = createBill(room, PricingSettings(), draft)
        assertEquals("530", bill.total)
        assertEquals(room.recurringCharges, bill.customCharges)
        assertEquals(emptyList<CustomCharge>(), room.chargesForBill(BillDraft(), bill))
        assertEquals(bill.customCharges, room.copy(recurringCharges = listOf(CustomCharge("网络费", "50"))).chargesForBill(null, bill))
    }
}
