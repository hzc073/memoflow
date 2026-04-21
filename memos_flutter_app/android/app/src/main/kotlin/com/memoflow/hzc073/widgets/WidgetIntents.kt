package com.memoflow.hzc073.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.memoflow.hzc073.MainActivity

object WidgetIntents {
    const val EXTRA_WIDGET_ACTION = "memoflow_widget_action"
    const val EXTRA_MEMO_UID = "memoflow_widget_memo_uid"
    const val EXTRA_DAY_EPOCH_SEC = "memoflow_widget_day_epoch_sec"

    const val ACTION_DAILY_REVIEW = "dailyReview"
    const val ACTION_QUICK_INPUT = "quickInput"
    const val ACTION_CALENDAR = "calendar"
    const val ACTION_STATS = "stats"

    private fun intentActionWidget(context: Context) =
        "${context.packageName}.WIDGET_ACTION"

    fun normalizeAction(raw: String?): String? {
        val normalized = raw?.trim().orEmpty()
        return when (normalized) {
            ACTION_DAILY_REVIEW -> ACTION_DAILY_REVIEW
            ACTION_QUICK_INPUT -> ACTION_QUICK_INPUT
            ACTION_CALENDAR, ACTION_STATS -> ACTION_CALENDAR
            else -> null
        }
    }

    fun buildLaunchIntent(
        context: Context,
        action: String? = null,
        memoUid: String? = null,
        dayEpochSec: Long? = null,
    ): Intent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP,
        )
        val normalizedAction = normalizeAction(action)
        if (normalizedAction != null) {
            intent.action = intentActionWidget(context)
            intent.putExtra(EXTRA_WIDGET_ACTION, normalizedAction)
        }
        if (!memoUid.isNullOrBlank()) {
            intent.putExtra(EXTRA_MEMO_UID, memoUid)
        }
        if (dayEpochSec != null && dayEpochSec > 0L) {
            intent.putExtra(EXTRA_DAY_EPOCH_SEC, dayEpochSec)
        }
        return intent
    }

    fun launchApp(
        context: Context,
        action: String? = null,
        memoUid: String? = null,
        dayEpochSec: Long? = null,
        requestCode: Int? = null,
    ): PendingIntent {
        val intent = buildLaunchIntent(
            context = context,
            action = action,
            memoUid = memoUid,
            dayEpochSec = dayEpochSec,
        )
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val resolvedRequestCode = requestCode ?: listOf(action.orEmpty(), memoUid.orEmpty(), dayEpochSec?.toString().orEmpty())
            .joinToString("|")
            .hashCode()
        return PendingIntent.getActivity(context, resolvedRequestCode, intent, flags)
    }
}
