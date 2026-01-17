package com.memoflow.hzc073.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.memoflow.hzc073.R

class QuickInputWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_input)
            val pendingIntent = WidgetIntents.launchApp(context, WidgetIntents.ACTION_QUICK_INPUT)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_quick_action, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
