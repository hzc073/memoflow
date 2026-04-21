package com.memoflow.hzc073.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import com.memoflow.hzc073.R

class DailyReviewWidgetProvider : AppWidgetProvider() {
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        ensureRotation(context)
    }

    override fun onDisabled(context: Context) {
        cancelRotation(context)
        super.onDisabled(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
        ensureRotation(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            actionOpenCurrent(context) -> {
                handleOpenCurrent(context)
                return
            }
            actionRotate(context) -> {
                WidgetDailyReviewStore.rotateIfDue(context, force = true)
                updateAllWidgets(context)
                ensureRotation(context)
                return
            }
        }
        super.onReceive(context, intent)
    }

    companion object {
        private const val REQUEST_OPEN = 7001
        private const val REQUEST_ROTATE = 7002

        private fun actionOpenCurrent(context: Context) =
            "${context.packageName}.widget.dailyReview.OPEN_CURRENT"

        private fun actionRotate(context: Context) =
            "${context.packageName}.widget.dailyReview.ROTATE"

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, DailyReviewWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            updateWidgets(context, appWidgetManager, ids)
        }

        fun ensureRotation(context: Context) {
            if (!hasWidgets(context)) {
                cancelRotation(context)
                return
            }
            if (WidgetDailyReviewStore.load(context).items.size <= 1) {
                cancelRotation(context)
                return
            }
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            alarmManager.cancel(rotationPendingIntent(context))
            val triggerDelay = WidgetDailyReviewStore.remainingUntilNextRotationMs(context).coerceAtLeast(1L)
            val triggerAtMillis = android.os.SystemClock.elapsedRealtime() + triggerDelay
            alarmManager.setInexactRepeating(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAtMillis,
                WidgetDailyReviewStore.intervalMs(),
                rotationPendingIntent(context),
            )
        }

        fun cancelRotation(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            alarmManager.cancel(rotationPendingIntent(context))
        }

        fun hasWidgets(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            return manager.getAppWidgetIds(
                ComponentName(context, DailyReviewWidgetProvider::class.java),
            ).isNotEmpty()
        }

        fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
        ) {
            WidgetDailyReviewStore.rotateIfDue(context)
            val data = WidgetDailyReviewStore.load(context)
            val item = WidgetDailyReviewStore.currentItem(context)
            val avatarSizePx = (context.resources.displayMetrics.density * 30f).toInt()
            val avatarBitmap = WidgetDailyReviewStore.avatarBitmap(context, avatarSizePx)
            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.widget_daily_review)
                views.setTextViewText(R.id.widget_countdown, item?.dateLabel ?: data.title)
                views.setTextViewText(R.id.widget_excerpt, item?.excerpt ?: data.fallbackBody)
                if (avatarBitmap != null) {
                    views.setImageViewBitmap(R.id.widget_avatar, avatarBitmap)
                } else {
                    views.setImageViewResource(R.id.widget_avatar, R.mipmap.ic_launcher)
                }
                views.setOnClickPendingIntent(R.id.widget_root, openCurrentPendingIntent(context))
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }

        private fun handleOpenCurrent(context: Context) {
            val item = WidgetDailyReviewStore.currentItem(context)
            val launchIntent = WidgetIntents.buildLaunchIntent(
                context,
                action = WidgetIntents.ACTION_DAILY_REVIEW,
                memoUid = item?.memoUid,
            )
            context.startActivity(launchIntent)
            WidgetDailyReviewStore.advance(context)
            updateAllWidgets(context)
            ensureRotation(context)
        }

        private fun openCurrentPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, DailyReviewWidgetProvider::class.java).apply {
                action = actionOpenCurrent(context)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }
            return PendingIntent.getBroadcast(context, REQUEST_OPEN, intent, flags)
        }

        private fun rotationPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, DailyReviewWidgetProvider::class.java).apply {
                action = actionRotate(context)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }
            return PendingIntent.getBroadcast(context, REQUEST_ROTATE, intent, flags)
        }
    }
}
