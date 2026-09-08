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
}
