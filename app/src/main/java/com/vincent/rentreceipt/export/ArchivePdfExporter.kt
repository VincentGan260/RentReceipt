package com.vincent.rentreceipt.export

import android.content.ContentValues
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.res.ResourcesCompat
import com.vincent.rentreceipt.R
import com.vincent.rentreceipt.model.Bill
import com.vincent.rentreceipt.model.Building
import com.vincent.rentreceipt.model.DepositStatus
import com.vincent.rentreceipt.model.Room
import com.vincent.rentreceipt.model.resolvedElectricityUsage
import com.vincent.rentreceipt.model.resolvedWaterUsage
import com.vincent.rentreceipt.model.roomNumberComparator
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.YearMonth

object ArchivePdfExporter {
    private const val PAGE_WIDTH = 842
    private const val PAGE_HEIGHT = 595
    private const val MARGIN = 30f
    private const val ROW_HEIGHT = 28f
    private const val HEADER_HEIGHT = 44f
    private const val ROOMS_PER_PAGE = 15
    private const val MONTHS_PER_PAGE = 3

    fun export(
        context: Context,
        building: Building,
        rooms: List<Room>,
        bills: List<Bill>,
        startMonth: YearMonth,
        endMonth: YearMonth
    ): Uri {
        require(!endMonth.isBefore(startMonth)) { "结束月份不能早于开始月份" }
        val months = generateSequence(startMonth) { month ->
            month.plusMonths(1).takeUnless { it.isAfter(endMonth) }
        }.toList()
        val filename = "${building.name}_${startMonth}_至_${endMonth}_房屋留档.pdf"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOCUMENTS}/房租留档/${building.name}"
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val timesNewRoman = checkNotNull(
            ResourcesCompat.getFont(context, R.font.times_new_roman_bold)
        ) { "应用内置的 Times New Roman 字体无法加载" }
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = checkNotNull(resolver.insert(collection, values)) { "无法创建留档 PDF" }
        val document = PdfDocument()
        try {
            val roomPages = rooms
                .sortedWith { left, right -> roomNumberComparator.compare(left.number, right.number) }
                .chunked(ROOMS_PER_PAGE)
                .ifEmpty { listOf(emptyList()) }
            val monthPages = months.chunked(MONTHS_PER_PAGE)
            val pageCount = roomPages.size * monthPages.size
            var pageNumber = 0
            monthPages.forEach { monthGroup ->
                roomPages.forEach { roomGroup ->
                    pageNumber++
                    val page = document.startPage(
                        PdfDocument.PageInfo.Builder(PAGE_WIDTH, PAGE_HEIGHT, pageNumber).create()
                    )
                    drawPage(
                        page.canvas, building, roomGroup, bills, monthGroup,
                        startMonth, endMonth, pageNumber, pageCount, timesNewRoman
                    )
                    document.finishPage(page)
                }
            }
            resolver.openOutputStream(uri, "w").use { output ->
                checkNotNull(output) { "无法写入留档 PDF" }
                document.writeTo(output)
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        } finally {
            document.close()
        }
        return uri
    }

    private fun drawPage(
        canvas: Canvas,
        building: Building,
        rooms: List<Room>,
        bills: List<Bill>,
        months: List<YearMonth>,
        startMonth: YearMonth,
        endMonth: YearMonth,
        pageNumber: Int,
        pageCount: Int,
        timesNewRoman: Typeface
    ) {
        canvas.drawColor(Color.WHITE)
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(45, 45, 45)
            style = Paint.Style.STROKE
            strokeWidth = 0.8f
        }
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(35, 35, 35)
            typeface = Typeface.create("serif", Typeface.NORMAL)
            textSize = 9f
        }
        val title = Paint(text).apply {
            textSize = 17f
            typeface = Typeface.create("serif", Typeface.BOLD)
        }
        val numberText = Paint(text).apply {
            typeface = timesNewRoman
        }
        val numberTitle = Paint(title).apply { typeface = timesNewRoman }
        drawMixedText(
            canvas,
            "${building.name} 房屋水电留档  $startMonth 至 $endMonth",
            MARGIN, 32f, title, numberTitle
        )

        val tableTop = 52f
        val roomWidth = 66f
        val occupiedWidth = 46f
        val rentWidth = 52f
        val depositWidth = 72f
        val fixedWidth = roomWidth + occupiedWidth + rentWidth + depositWidth
        val tableWidth = PAGE_WIDTH - MARGIN * 2
        val monthWidth = (tableWidth - fixedWidth) / months.size
        val xs = mutableListOf(MARGIN)
        listOf(roomWidth, occupiedWidth, rentWidth, depositWidth).forEach { xs += xs.last() + it }
        months.forEach { xs += xs.last() + monthWidth }
        val tableBottom = tableTop + HEADER_HEIGHT + (rooms.size + 1) * ROW_HEIGHT

        xs.forEach { x -> canvas.drawLine(x, tableTop, x, tableBottom, line) }
        canvas.drawLine(MARGIN, tableTop, MARGIN + tableWidth, tableTop, line)
        canvas.drawLine(MARGIN, tableTop + HEADER_HEIGHT, MARGIN + tableWidth, tableTop + HEADER_HEIGHT, line)
        (0..rooms.size).forEach { index ->
            val y = tableTop + HEADER_HEIGHT + (index + 1) * ROW_HEIGHT
            canvas.drawLine(MARGIN, y, MARGIN + tableWidth, y, line)
        }

        val fixedLabels = listOf("房号", "出租", "租金", "押金")
        fixedLabels.forEachIndexed { index, label ->
            centeredText(canvas, label, xs[index], xs[index + 1], tableTop + 27f, text)
        }
        months.forEachIndexed { index, month ->
            val left = xs[index + 4]
            val right = xs[index + 5]
            centeredText(canvas, "${month.year}.${month.monthValue}", left, right, tableTop + 15f, numberText)
            canvas.drawLine(left, tableTop + 20f, right, tableTop + 20f, line)
            val first = left + (right - left) / 3f
            val second = left + (right - left) * 2f / 3f
            canvas.drawLine(first, tableTop + 20f, first, tableBottom, line)
            canvas.drawLine(second, tableTop + 20f, second, tableBottom, line)
            centeredText(canvas, "水(m³)", left, first, tableTop + 37f, text)
            centeredText(canvas, "电(度)", first, second, tableTop + 37f, text)
            centeredText(canvas, "总额(元)", second, right, tableTop + 37f, text)
        }

        val billMap = bills.associateBy { it.roomId to it.month }
        rooms.forEachIndexed { rowIndex, room ->
            val baseline = tableTop + HEADER_HEIGHT + rowIndex * ROW_HEIGHT + 18f
            val deposit = "${whole(room.depositAmount)}/${depositLabel(room.depositStatus)}"
            centeredText(canvas, room.number, xs[0], xs[1], baseline, numberText)
            centeredText(canvas, if (room.occupied) "已租" else "空置", xs[1], xs[2], baseline, text)
            centeredText(canvas, whole(room.rent), xs[2], xs[3], baseline, numberText)
            centeredMixedText(canvas, deposit, xs[3], xs[4], baseline, text, numberText)
            months.forEachIndexed { monthIndex, month ->
                val bill = billMap[room.id to month.toString()]
                val left = xs[monthIndex + 4]
                val right = xs[monthIndex + 5]
                val first = left + (right - left) / 3f
                val second = left + (right - left) * 2f / 3f
                centeredText(
                    canvas,
                    bill?.resolvedWaterUsage() ?: "-",
                    left, first, baseline, numberText
                )
                centeredText(
                    canvas,
                    bill?.resolvedElectricityUsage() ?: "-",
                    first, second, baseline, numberText
                )
                centeredText(canvas, bill?.total ?: "-", second, right, baseline, numberText)
            }
        }
        val summaryBaseline = tableTop + HEADER_HEIGHT + rooms.size * ROW_HEIGHT + 18f
        centeredText(canvas, "月汇总", xs[0], xs[1], summaryBaseline, text)
        centeredText(canvas, "费用", xs[1], xs[4], summaryBaseline, text)
        months.forEachIndexed { monthIndex, month ->
            val monthBills = bills.filter { it.month == month.toString() }
            val waterTotal = monthBills.sumOf { it.waterAmount.toBigDecimalOrNull() ?: BigDecimal.ZERO }
            val electricityTotal = monthBills.sumOf { it.electricityAmount.toBigDecimalOrNull() ?: BigDecimal.ZERO }
            val grandTotal = monthBills.sumOf { it.total.toBigDecimalOrNull() ?: BigDecimal.ZERO }
            val left = xs[monthIndex + 4]
            val right = xs[monthIndex + 5]
            val first = left + (right - left) / 3f
            val second = left + (right - left) * 2f / 3f
            centeredText(canvas, whole(waterTotal), left, first, summaryBaseline, numberText)
            centeredText(canvas, whole(electricityTotal), first, second, summaryBaseline, numberText)
            centeredText(canvas, whole(grandTotal), second, right, summaryBaseline, numberText)
        }
        text.textSize = 8f
        canvas.drawText("水量、电量为当月实际用量；总额为每房当月应收；月汇总行为全楼费用。", MARGIN, PAGE_HEIGHT - 22f, text)
        val pageText = "第 $pageNumber / $pageCount 页"
        numberText.textSize = 8f
        centeredMixedText(
            canvas,
            pageText,
            PAGE_WIDTH - MARGIN - mixedTextWidth(pageText, text, numberText),
            PAGE_WIDTH - MARGIN,
            PAGE_HEIGHT - 22f,
            text,
            numberText
        )
    }

    private fun drawMixedText(
        canvas: Canvas,
        value: String,
        x: Float,
        baseline: Float,
        serifPaint: Paint,
        timesPaint: Paint
    ) {
        var cursor = x
        value.groupByTypeface().forEach { (part, useTimes) ->
            val paint = if (useTimes) timesPaint else serifPaint
            canvas.drawText(part, cursor, baseline, paint)
            cursor += paint.measureText(part)
        }
    }

    private fun centeredMixedText(
        canvas: Canvas,
        value: String,
        left: Float,
        right: Float,
        baseline: Float,
        serifPaint: Paint,
        timesPaint: Paint
    ) {
        val width = mixedTextWidth(value, serifPaint, timesPaint)
        canvas.save()
        canvas.clipRect(left + 2f, 0f, right - 2f, PAGE_HEIGHT.toFloat())
        drawMixedText(canvas, value, (left + right - width) / 2f, baseline, serifPaint, timesPaint)
        canvas.restore()
    }

    private fun mixedTextWidth(value: String, serifPaint: Paint, timesPaint: Paint): Float =
        value.groupByTypeface().sumOf { (part, useTimes) ->
            (if (useTimes) timesPaint else serifPaint).measureText(part).toDouble()
        }.toFloat()

    private fun String.groupByTypeface(): List<Pair<String, Boolean>> {
        if (isEmpty()) return emptyList()
        val result = mutableListOf<Pair<String, Boolean>>()
        val current = StringBuilder()
        var currentUsesTimes = first().usesTimesNewRoman()
        forEach { character ->
            val usesTimes = character.usesTimesNewRoman()
            if (usesTimes != currentUsesTimes && current.isNotEmpty()) {
                result += current.toString() to currentUsesTimes
                current.clear()
            }
            current.append(character)
            currentUsesTimes = usesTimes
        }
        if (current.isNotEmpty()) result += current.toString() to currentUsesTimes
        return result
    }

    private fun Char.usesTimesNewRoman(): Boolean = code in 0x20..0x7E || this == '³'

    private fun centeredText(
        canvas: Canvas,
        value: String,
        left: Float,
        right: Float,
        baseline: Float,
        paint: Paint
    ) {
        canvas.save()
        canvas.clipRect(left + 2f, 0f, right - 2f, PAGE_HEIGHT.toFloat())
        canvas.drawText(value, (left + right - paint.measureText(value)) / 2f, baseline, paint)
        canvas.restore()
    }

    private fun whole(value: String): String = whole(value.toBigDecimalOrNull() ?: BigDecimal.ZERO)
    private fun whole(value: BigDecimal): String = value.setScale(0, RoundingMode.HALF_UP).toPlainString()

    private fun depositLabel(status: DepositStatus) = when (status) {
        DepositStatus.NOT_COLLECTED -> "未收"
        DepositStatus.COLLECTED -> "已收"
        DepositStatus.REFUNDED -> "已退"
    }
}
