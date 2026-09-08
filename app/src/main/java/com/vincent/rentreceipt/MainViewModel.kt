package com.vincent.rentreceipt

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import com.vincent.rentreceipt.data.RentRepository
import com.vincent.rentreceipt.model.Bill
import com.vincent.rentreceipt.model.BillDraft
import com.vincent.rentreceipt.model.AppData
import com.vincent.rentreceipt.model.Building
import com.vincent.rentreceipt.model.PricingSettings
import com.vincent.rentreceipt.model.Room
import com.vincent.rentreceipt.model.ReceiptTemplate

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = RentRepository(application)
    val data = repository.data
    fun saveBuilding(building: Building) = repository.saveBuilding(building)
    fun saveBuildingSettings(buildingId: String, settings: PricingSettings) =
        repository.saveBuildingSettings(buildingId, settings)
    fun saveGlobalReceiptTemplate(template: ReceiptTemplate) =
        repository.saveGlobalReceiptTemplate(template)
    fun saveRoom(room: Room) = repository.saveRoom(room)
    fun saveRooms(rooms: List<Room>) = repository.saveRooms(rooms)
    fun deleteRoom(roomId: String) = repository.deleteRoom(roomId)
    fun saveBill(bill: Bill) = repository.saveBill(bill)
    fun markMonthPaid(buildingId: String, month: String, paidDate: String) =
        repository.markMonthPaid(buildingId, month, paidDate)
    fun saveBills(bills: List<Bill>) = repository.saveBills(bills)
    fun loadBillDraft(buildingId: String, roomId: String, month: String) =
        repository.loadBillDraft(buildingId, roomId, month)
    fun saveBillDraft(buildingId: String, roomId: String, draft: BillDraft) =
        repository.saveBillDraft(buildingId, roomId, draft)
    fun replaceAll(data: AppData) = repository.replaceAll(data)
}
