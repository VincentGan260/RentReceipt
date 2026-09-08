package com.vincent.rentreceipt.export

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.res.ResourcesCompat
import com.vincent.rentreceipt.R
import com.vincent.rentreceipt.model.Bill
import com.vincent.rentreceipt.model.ReceiptTemplate
import com.vincent.rentreceipt.model.ReceiptTextElement
import com.vincent.rentreceipt.model.resolvedElectricityUsage
import com.vincent.rentreceipt.model.resolvedWaterUsage
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDate
import java.time.YearMonth

object ReceiptExporter {
    const val WIDTH = 3508
    const val HEIGHT = 1970
    private const val CUSTOM_ROW_HEIGHT = 240f
    private const val BLUE = 0xFF124997.toInt()
    private const val RED = 0xFF9A1824.toInt()
    private const val INK = 0xFF252525.toInt()
    private const val PAPER = 0xFFFFFCF4.toInt()
    private const val DETAIL_LABEL_SIZE = 66f
    private const val DETAIL_VALUE_SIZE = 136f
    fun export(context: Context, bill: Bill, buildingName: String, template: ReceiptTemplate): Uri {
        val bitmap = createBitmap(context, bill, template)
        val filename = "${bill.month}-${buildingName}-${bill.roomNumber}房-房租单.png"
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, filename)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(
                MediaStore.Images.Media.RELATIVE_PATH,
                "${Environment.DIRECTORY_PICTURES}/房租单/$buildingName/${bill.month}"
            )
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = checkNotNull(resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)) {
            "无法创建图片文件"
        }
        try {
            resolver.openOutputStream(uri).use { stream ->
                checkNotNull(stream) { "无法写入图片" }
                check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) { "图片保存失败" }
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        } finally {
            bitmap.recycle()
        }
        return uri
    }

    fun exportBatch(
        context: Context,
        bills: List<Bill>,
        buildingName: String,
        template: ReceiptTemplate
    ): Int {
        bills.forEach { export(context, it, buildingName, template) }
        return bills.size
    }

    fun heightFor(bill: Bill): Int = HEIGHT + (bill.customCharges.size * CUSTOM_ROW_HEIGHT).toInt()

    private fun createBitmap(context: Context, bill: Bill, template: ReceiptTemplate): Bitmap =
        Bitmap.createBitmap(WIDTH, heightFor(bill), Bitmap.Config.ARGB_8888).also {
            drawReceipt(Canvas(it), bill, template, timesNewRoman(context))
        }

    fun createPreviewBitmap(context: Context, bill: Bill, template: ReceiptTemplate): Bitmap {
        val scale = 0.4f
        return Bitmap.createBitmap(
            (WIDTH * scale).toInt(),
            (heightFor(bill) * scale).toInt(),
            Bitmap.Config.ARGB_8888
        ).also {
            val canvas = Canvas(it)
            canvas.scale(scale, scale)
            drawReceipt(canvas, bill, template, timesNewRoman(context))
        }
    }

    fun share(context: Context, uri: Uri) {
        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, "分享房租单"))
    }

    private fun timesNewRoman(context: Context): Typeface = checkNotNull(
        ResourcesCompat.getFont(context, R.font.times_new_roman_bold)
    ) { "应用内置的 Times New Roman 字体无法加载" }

    private fun drawReceipt(
        canvas: Canvas,
        bill: Bill,
        template: ReceiptTemplate,
        timesNewRoman: Typeface
    ) {
        canvas.drawColor(PAPER)
        canvas.translate(0f, 70f)
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = INK; style = Paint.Style.STROKE; strokeWidth = 5f }
        val body = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = INK; typeface = Typeface.create("serif", Typeface.BOLD) }
        val blue = Paint(body).apply { color = BLUE; typeface = timesNewRoman }
        val red = Paint(blue).apply { color = RED }
        val fangSong = Typeface.create("serif", Typeface.BOLD)

        val customOffset = bill.customCharges.size * CUSTOM_ROW_HEIGHT
        val left = 95f; val right = WIDTH - 95f; val top = 285f; val bottom = 1800f + customOffset
        val detailsBottom = 1400f + customOffset
        val cols = floatArrayOf(left, 620f, 1100f, 1580f, 2060f, right)
        val rows = buildList {
            add(500f); add(800f); add(1100f); add(1400f)
            repeat(bill.customCharges.size) { add(1400f + (it + 1) * CUSTOM_ROW_HEIGHT) }
            add(bottom)
        }.distinct()
        canvas.drawRect(left, top, right, bottom, border)
        cols.drop(1).dropLast(1).forEach { x -> canvas.drawLine(x, top, x, detailsBottom, border) }
        rows.forEach { y -> canvas.drawLine(left, y, right, y, border) }

        bill.customCharges.forEachIndexed { index, charge ->
            val rowTop = 1400f + index * CUSTOM_ROW_HEIGHT
            val rowBottom = rowTop + CUSTOM_ROW_HEIGHT
            drawCenteredText(canvas, charge.name, RectF(left, rowTop, 620f, rowBottom), body, DETAIL_LABEL_SIZE)
            drawCenteredText(canvas, charge.amount, RectF(2060f, rowTop, right, rowBottom), blue, DETAIL_VALUE_SIZE)
        }

        template.elements.forEach { element ->
            if (element.id == "date") {
                drawStyledDate(canvas, bill, element, body, timesNewRoman)
                return@forEach
            }
            val paint = when (element.color) {
                "blue" -> blue
                "red" -> red
                else -> body
            }
            paint.typeface = when {
                element.id == "totalUpper" -> fangSong
                element.id in numericElementIds -> timesNewRoman
                element.color == "blue" || element.color == "red" -> timesNewRoman
                else -> Typeface.create("serif", Typeface.BOLD)
            }
            fittedText(canvas, resolveReceiptText(element, bill), element, paint, customOffset)
        }
    }

    fun resolveReceiptText(element: ReceiptTextElement, bill: Bill): String {
        val date = receiptDate(bill)
        val replacements = mapOf(
            "{room}" to bill.roomNumber,
            "{receiptNo}" to bill.month.replace("-", "") + bill.roomNumber,
            "{date}" to "${date.year} 年 ${date.monthValue} 月 ${date.dayOfMonth} 日",
            "{currentWater}" to bill.currentWater,
            "{previousWater}" to bill.previousWater,
            "{waterUsage}" to bill.resolvedWaterUsage(),
            "{waterRate}" to bill.waterRate,
            "{waterAmount}" to bill.waterAmount,
            "{currentElectricity}" to bill.currentElectricity,
            "{previousElectricity}" to bill.previousElectricity,
            "{electricityUsage}" to bill.resolvedElectricityUsage(),
            "{electricityRate}" to bill.electricityRate,
            "{electricityAmount}" to bill.electricityAmount,
            "{rent}" to bill.rent,
            "{totalUpper}" to rmbUpper(decimal(bill.total)),
            "{total}" to bill.total
        )
        return replacements.entries.fold(element.content) { value, entry ->
            value.replace(entry.key, entry.value)
        }
    }

    private fun drawStyledDate(
        canvas: Canvas,
        bill: Bill,
        element: ReceiptTextElement,
        bodyPaint: Paint,
        numberTypeface: Typeface
    ) {
        val date = receiptDate(bill)
        val numberPaint = Paint(bodyPaint).apply {
            color = BLUE
            typeface = numberTypeface
            style = Paint.Style.FILL
        }
        val labelPaint = Paint(bodyPaint).apply {
            color = INK
            typeface = Typeface.create("serif", Typeface.BOLD)
            style = Paint.Style.FILL
        }
        val parts = listOf(
            date.year.toString() to numberPaint,
            " 年 " to labelPaint,
            date.monthValue.toString() to numberPaint,
            " 月 " to labelPaint,
            date.dayOfMonth.toString() to numberPaint,
            " 日" to labelPaint
        )
        var size = element.fontSize
        parts.forEach { (_, paint) -> paint.textSize = size }
        var totalWidth = parts.sumOf { (value, paint) -> paint.measureText(value).toDouble() }.toFloat()
        if (totalWidth > 850f) {
            size *= 850f / totalWidth
            parts.forEach { (_, paint) -> paint.textSize = size }
            totalWidth = parts.sumOf { (value, paint) -> paint.measureText(value).toDouble() }.toFloat()
        }
        var x = element.x.coerceIn(95f, WIDTH - 95f - totalWidth)
        parts.forEach { (value, paint) ->
            canvas.drawText(value, x, element.y, paint)
            x += paint.measureText(value)
        }
    }

    private fun receiptDate(bill: Bill): LocalDate = runCatching {
        YearMonth.parse(bill.month).atDay(1)
    }.getOrElse {
        runCatching { LocalDate.parse(bill.createdDate) }.getOrElse { LocalDate.now() }
    }

    private fun fittedText(
        canvas: Canvas,
        value: String,
        element: ReceiptTextElement,
        paint: Paint,
        customOffset: Float
    ) {
        val bounds = receiptCellBounds(element.id, customOffset)
        val maxWidth = bounds?.let { it.width() - 40f } ?: when (element.id) {
            "title" -> 2500f
            "room" -> 260f
            "receiptNo" -> 620f
            "date" -> 850f
            "headItem", "waterLabel", "electricLabel", "rentLabel" -> 430f
            "headCurrent", "headPrevious", "headUsage", "waterCurrent", "waterPrevious",
            "waterUsage", "electricCurrent", "electricPrevious", "electricUsage", "rentUsage" -> 430f
            "headAmount", "waterAmount", "electricAmount", "rentAmount" -> 1200f
            "totalUpper" -> 1700f
            "total" -> 650f
            else -> WIDTH - 190f
        }
        paint.textSize = when (element.id) {
            in detailLabelIds -> DETAIL_LABEL_SIZE
            in detailValueIds -> DETAIL_VALUE_SIZE
            else -> element.fontSize
        }
        val measured = paint.measureText(value)
        if (measured > maxWidth) paint.textSize *= maxWidth / measured
        paint.style = Paint.Style.FILL
        val width = paint.measureText(value)
        val desiredX = when {
            bounds != null -> bounds.centerX() - width / 2f
            element.centered -> element.x - width / 2f
            else -> element.x
        }
        val safeX = desiredX.coerceIn(95f, WIDTH - 95f - width)
        val baseline = bounds?.let {
            val metrics = paint.fontMetrics
            it.centerY() - (metrics.ascent + metrics.descent) / 2f
        } ?: element.y
        canvas.drawText(value, safeX, baseline, paint)
    }

    private fun drawCenteredText(
        canvas: Canvas,
        value: String,
        bounds: RectF,
        sourcePaint: Paint,
        fontSize: Float
    ) {
        val paint = Paint(sourcePaint).apply { textSize = fontSize; style = Paint.Style.FILL }
        val maxWidth = bounds.width() - 40f
        val measured = paint.measureText(value)
        if (measured > maxWidth && measured > 0f) paint.textSize *= maxWidth / measured
        val metrics = paint.fontMetrics
        canvas.drawText(
            value,
            bounds.centerX() - paint.measureText(value) / 2f,
            bounds.centerY() - (metrics.ascent + metrics.descent) / 2f,
            paint
        )
    }

    private fun receiptCellBounds(id: String, customOffset: Float): RectF? {
        val left = 95f
        val right = WIDTH - 95f
        val columns = mapOf(
            "Item" to (left to 620f),
            "Current" to (620f to 1100f),
            "Previous" to (1100f to 1580f),
            "Usage" to (1580f to 2060f),
            "Amount" to (2060f to right)
        )
        val row = when {
            id.startsWith("head") -> 285f to 500f
            id.startsWith("water") -> 500f to 800f
            id.startsWith("electric") -> 800f to 1100f
            id.startsWith("rent") -> 1100f to 1400f
            id.startsWith("total") -> (1400f + customOffset) to (1800f + customOffset)
            else -> return null
        }
        if (id == "totalLabel") return RectF(left, row.first, 620f, row.second)
        if (id == "totalUpper") return RectF(620f, row.first, 2440f, row.second)
        if (id == "total") return RectF(2440f, row.first, right, row.second)
        val column = if (id.endsWith("Label")) {
            columns.getValue("Item")
        } else {
            columns.entries.firstOrNull { id.endsWith(it.key) }?.value ?: return null
        }
        return RectF(column.first, row.first, column.second, row.second)
    }

    private val numericElementIds = setOf(
        "room", "receiptNo",
        "waterCurrent", "waterPrevious", "waterUsage", "waterRate", "waterAmount",
        "electricCurrent", "electricPrevious", "electricUsage", "electricRate", "electricAmount",
        "rentUsage", "rentAmount", "total"
    )

    private val detailLabelIds = setOf(
        "headItem", "headCurrent", "headPrevious", "headUsage", "headAmount",
        "waterLabel", "electricLabel", "rentLabel"
    )

    private val detailValueIds = setOf(
        "waterCurrent", "waterPrevious", "waterUsage", "waterAmount",
        "electricCurrent", "electricPrevious", "electricUsage", "electricAmount",
        "rentUsage", "rentAmount"
    )

    private fun decimal(value: String) = value.toBigDecimalOrNull() ?: BigDecimal.ZERO
    private fun plain(value: BigDecimal) = value.stripTrailingZeros().toPlainString()

    fun rmbUpper(amount: BigDecimal): String {
        val digits = "零壹贰叁肆伍陆柒捌玖"
        val units = arrayOf("", "拾", "佰", "仟")
        val sections = arrayOf("", "万", "亿", "兆")
        val cents = amount.setScale(2, RoundingMode.HALF_UP).movePointRight(2).longValueExact()
        val integer = cents / 100
        val fraction = (cents % 100).toInt()
        if (integer == 0L && fraction == 0) return "零元整"
        var n = integer
        var sectionIndex = 0
        var result = ""
        var pendingZero = false
        while (n > 0) {
            val section = (n % 10000).toInt()
            if (section == 0) {
                pendingZero = result.isNotEmpty()
            } else {
                val sectionText = sectionUpper(section, digits, units)
                result = (if (pendingZero || (section < 1000 && result.isNotEmpty())) "零" else "") +
                    sectionText + sections[sectionIndex] + result
                pendingZero = false
            }
            n /= 10000
            sectionIndex++
        }
        result = result.trimStart('零') + "元"
        val jiao = fraction / 10
        val fen = fraction % 10
        return result + when {
            fraction == 0 -> "整"
            jiao > 0 && fen > 0 -> "${digits[jiao]}角${digits[fen]}分"
            jiao > 0 -> "${digits[jiao]}角"
            else -> "零${digits[fen]}分"
        }
    }

    private fun sectionUpper(value: Int, digits: String, units: Array<String>): String {
        var n = value
        var position = 0
        var result = ""
        var zero = false
        while (n > 0) {
            val digit = n % 10
            if (digit == 0) {
                zero = result.isNotEmpty()
            } else {
                result = (if (zero) "零" else "") + digits[digit] + units[position] + result
                zero = false
            }
            n /= 10
            position++
        }
        return result
    }
}
