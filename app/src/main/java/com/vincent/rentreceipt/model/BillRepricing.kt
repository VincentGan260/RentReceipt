package com.vincent.rentreceipt.model

/** Reprice a saved bill without changing its meter usage, identity or payment record. */
fun Bill.reprice(room: Room, settings: PricingSettings, previousRoom: Room = room): Bill {
    val charges = customCharges.toMutableList()
    if (previousRoom.recurringCharges != room.recurringCharges) {
        previousRoom.recurringCharges.forEach { old ->
            val index = charges.indexOfFirst {
                it.name == old.name.trim() && it.amount.toDecimal().compareTo(old.amount.toDecimal().whole()) == 0
            }
            if (index >= 0) charges.removeAt(index)
        }
        charges += room.recurringCharges
    }
    val recalculated = createBill(room, settings, BillDraft(
        month = month,
        previousWater = previousWater,
        currentWater = currentWater,
        previousElectricity = previousElectricity,
        currentElectricity = currentElectricity,
        rentOnly = rentOnly,
        waterUsageOverride = resolvedWaterUsage(),
        electricityUsageOverride = resolvedElectricityUsage(),
        customCharges = charges
    ))
    return recalculated.copy(id = id, createdDate = createdDate, paid = paid, paidDate = paidDate)
}

fun Room.billingFees(settings: PricingSettings): List<Any?> = listOf(
    rent.toDecimal().stripTrailingZeros(),
    (customWaterRate ?: settings.defaultWaterRate).toDecimal().stripTrailingZeros(),
    (customElectricityRate ?: settings.defaultElectricityRate).toDecimal().stripTrailingZeros(),
    (customManagementRate ?: settings.defaultManagementRate ?: "0").toDecimal().stripTrailingZeros(),
    recurringCharges.map { it.name.trim() to it.amount.toDecimal().stripTrailingZeros() }
)
