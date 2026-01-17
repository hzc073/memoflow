package com.memoflow.hzc073.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.memoflow.hzc073.MainActivity

object WidgetIntents {
    const val EXTRA_WIDGET_ACTION = "memoflow_widget_action"
    const val ACTION_DAILY_REVIEW = "dailyReview"
    const val ACTION_QUICK_INPUT = "quickInput"
    const val ACTION_STATS = "stats"
    private const val INTENT_ACTION_WIDGET = "com.memoflow.hzc073.WIDGET_ACTION"

    fun launchApp(context: Context, action: String? = null): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        if (!action.isNullOrBlank()) {
            intent.action = INTENT_ACTION_WIDGET
            intent.putExtra(EXTRA_WIDGET_ACTION, action)
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val requestCode = action?.hashCode() ?: 0
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }
}
