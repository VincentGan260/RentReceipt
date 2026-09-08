package com.vincent.rentreceipt.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.vincent.rentreceipt.model.AppData

@Composable
fun HomeScreen(
    data: AppData,
    onSettings: () -> Unit,
    onImportRent: () -> Unit,
    onBatchBilling: () -> Unit,
    onEditRoom: (String) -> Unit,
    onPreview: (String) -> Unit
) {
    ExpressivePage(
        title = "房租单",
        actions = { KitIconButton(onClick = onSettings) { Icon(KitIcons.Settings, "收费设置") } }
    ) {
        item {
            ExpressiveCard(onClick = onImportRent) {
                Text("拍照导入房号与租金", style = KitTypography.headlineMedium)
                Text("拍摄整张租金表，自动按行配对，集中核对后一次保存。", style = KitTypography.bodyLarge)
            }
        }
        item {
            ExpressiveCard(
                onClick = if (data.rooms.isNotEmpty()) onBatchBilling else null
            ) {
                Text("批量抄录水电表", style = KitTypography.headlineMedium)
                Text("分别拍摄整张水表和电表，自动匹配全部房间并生成本月账单。", style = KitTypography.bodyLarge)
                if (data.rooms.isEmpty()) Text("请先拍租金表建立房间", color = KitColors.error)
            }
        }
        item {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("房间", style = KitTypography.headlineMedium, modifier = Modifier.weight(1f))
                Text("${data.rooms.size} 间", color = KitColors.onSurfaceVariant)
            }
        }
        if (data.rooms.isEmpty()) {
            item {
                Box(Modifier.fillMaxWidth().height(180.dp), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("尚未导入房间", style = KitTypography.titleLarge)
                        Text("拍摄租金表即可批量建立", color = KitColors.onSurfaceVariant)
                    }
                }
            }
        } else {
            items(data.rooms, key = { it.id }) { room ->
                val latest = data.bills.filter { it.roomId == room.id }.maxByOrNull { it.month }
                ExpressiveCard(modifier = Modifier.animateItem(), onClick = { onEditRoom(room.id) }) {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text("${room.number} 房", style = KitTypography.titleLarge)
                            Text("月租 ¥${room.rent}", style = KitTypography.bodyLarge)
                            Text(
                                "水 ¥${room.customWaterRate ?: data.settings.defaultWaterRate} / 电 ¥${room.customElectricityRate ?: data.settings.defaultElectricityRate}",
                                color = KitColors.onSurfaceVariant
                            )
                        }
                        if (latest != null) TextButton(
                            text = "${latest.month}\n¥${latest.total}",
                            onClick = { onPreview(latest.id) }
                        )
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}
