package com.memoflow.hzc073.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.widget.RemoteViews
import com.memoflow.hzc073.R

class StatsWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive action=${intent.action}")
        when (intent.action) {
            actionPreviousMonth(context) -> {
                Log.d(TAG, "previous month requested")
                WidgetCalendarStore.shiftDisplayedMonth(context, deltaMonths = -1)
                updateAllWidgets(context)
                return
            }
            actionNextMonth(context) -> {
                Log.d(TAG, "next month requested")
                WidgetCalendarStore.shiftDisplayedMonth(context, deltaMonths = 1)
                updateAllWidgets(context)
                return
            }
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d(TAG, "onUpdate ids=${appWidgetIds.joinToString()}")
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        private const val TAG = "StatsWidgetProvider"
        private const val REQUEST_PREVIOUS_MONTH = 9201
        private const val REQUEST_NEXT_MONTH = 9202

        private fun actionPreviousMonth(context: Context) =
            "${context.packageName}.widget.calendar.PREVIOUS_MONTH"

        private fun actionNextMonth(context: Context) =
            "${context.packageName}.widget.calendar.NEXT_MONTH"

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, StatsWidgetProvider::class.java),
            )
            Log.d(TAG, "updateAllWidgets ids=${ids.joinToString()} count=${ids.size}")
            if (ids.isEmpty()) return
            updateWidgets(context, appWidgetManager, ids)
        }

        fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
        ) {
            for (appWidgetId in appWidgetIds) {
                Log.d(TAG, "updateWidgets appWidgetId=$appWidgetId")
                val views = RemoteViews(context.packageName, R.layout.widget_stats)
                WidgetCalendarStore.applyToViews(context, views)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }

        fun changeMonthPendingIntent(context: Context, deltaMonths: Int): PendingIntent {
            val action = if (deltaMonths < 0) {
                actionPreviousMonth(context)
            } else {
                actionNextMonth(context)
            }
            val requestCode = if (deltaMonths < 0) REQUEST_PREVIOUS_MONTH else REQUEST_NEXT_MONTH
            Log.d(TAG, "create changeMonthPendingIntent deltaMonths=$deltaMonths action=$action requestCode=$requestCode")
            val intent = Intent(context, StatsWidgetProvider::class.java).apply {
                this.action = action
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }
            return PendingIntent.getBroadcast(context, requestCode, intent, flags)
        }
    }
}
