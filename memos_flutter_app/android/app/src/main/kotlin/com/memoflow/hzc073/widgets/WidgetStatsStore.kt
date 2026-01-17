package com.memoflow.hzc073.widgets

import android.content.Context
import android.widget.RemoteViews
import com.memoflow.hzc073.R

data class WidgetStatsData(
    val totalCount: Int,
    val days: IntArray,
    val title: String,
    val totalLabel: String,
    val rangeLabel: String,
)

object WidgetStatsStore {
    private const val prefsName = "memoflow_widget_stats"
    private const val keyTotal = "total_count"
    private const val keyDays = "days"
    private const val keyTitle = "title"
    private const val keyTotalLabel = "total_label"
    private const val keyRangeLabel = "range_label"

    private val dotIds = intArrayOf(
        R.id.heat_dot_0,
        R.id.heat_dot_1,
        R.id.heat_dot_2,
        R.id.heat_dot_3,
        R.id.heat_dot_4,
        R.id.heat_dot_5,
        R.id.heat_dot_6,
        R.id.heat_dot_7,
        R.id.heat_dot_8,
        R.id.heat_dot_9,
        R.id.heat_dot_10,
        R.id.heat_dot_11,
        R.id.heat_dot_12,
        R.id.heat_dot_13,
    )

    fun save(
        context: Context,
        totalCount: Int,
        days: IntArray,
        title: String,
        totalLabel: String,
        rangeLabel: String,
    ) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt(keyTotal, totalCount)
            .putString(keyDays, days.joinToString(","))
            .putString(keyTitle, title)
            .putString(keyTotalLabel, totalLabel)
            .putString(keyRangeLabel, rangeLabel)
            .apply()
    }

    fun load(context: Context): WidgetStatsData {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val total = prefs.getInt(keyTotal, 0)
        val days = parseDays(prefs.getString(keyDays, null))
        val title = prefs.getString(keyTitle, "笔记热力图") ?: "笔记热力图"
        val totalLabel = prefs.getString(keyTotalLabel, "总记录") ?: "总记录"
        val rangeLabel = prefs.getString(keyRangeLabel, "最近14天") ?: "最近14天"
        return WidgetStatsData(
            totalCount = total,
            days = days,
            title = title,
            totalLabel = totalLabel,
            rangeLabel = rangeLabel,
        )
    }

    fun applyToViews(context: Context, views: RemoteViews) {
        val data = load(context)
        views.setTextViewText(R.id.widget_title, data.title)
        views.setTextViewText(R.id.widget_total_count, data.totalCount.toString())
        views.setTextViewText(R.id.widget_total_label, data.totalLabel)
        views.setTextViewText(R.id.widget_range_label, data.rangeLabel)

        for (i in dotIds.indices) {
            val count = data.days.getOrNull(i) ?: 0
            val resId = when {
                count <= 0 -> R.drawable.widget_dot_cool
                count <= 2 -> R.drawable.widget_dot_warm
                else -> R.drawable.widget_dot_hot
            }
            views.setImageViewResource(dotIds[i], resId)
        }
    }

    private fun parseDays(raw: String?): IntArray {
        if (raw.isNullOrBlank()) return IntArray(14)
        val parts = raw.split(",")
        val out = IntArray(14)
        for (i in 0 until out.size) {
            if (i >= parts.size) break
            out[i] = parts[i].trim().toIntOrNull() ?: 0
        }
        return out
    }
}
