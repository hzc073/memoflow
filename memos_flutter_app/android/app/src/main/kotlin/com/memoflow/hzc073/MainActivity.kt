package com.memoflow.hzc073

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.memoflow.hzc073.widgets.DailyReviewWidgetProvider
import com.memoflow.hzc073.widgets.QuickInputWidgetProvider
import com.memoflow.hzc073.widgets.StatsWidgetProvider
import com.memoflow.hzc073.widgets.WidgetIntents
import com.memoflow.hzc073.widgets.WidgetStatsStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val widgetChannelName = "memoflow/widgets"
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: String? = null
    private var isFlutterUiReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        splashScreen.setKeepOnScreenCondition { !isFlutterUiReady }
        super.onCreate(savedInstanceState)
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        isFlutterUiReady = true
    }

    override fun onFlutterUiNoLongerDisplayed() {
        super.onFlutterUiNoLongerDisplayed()
        isFlutterUiReady = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannelName)
        widgetChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPinWidget" -> {
                    val type = call.argument<String>("type") ?: ""
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val appWidgetManager = AppWidgetManager.getInstance(this)
                    if (!appWidgetManager.isRequestPinAppWidgetSupported) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    val provider = when (type) {
                        "dailyReview" -> ComponentName(this, DailyReviewWidgetProvider::class.java)
                        "quickInput" -> ComponentName(this, QuickInputWidgetProvider::class.java)
                        "stats" -> ComponentName(this, StatsWidgetProvider::class.java)
                        else -> null
                    }

                    if (provider == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    appWidgetManager.requestPinAppWidget(provider, null, null)
                    result.success(true)
                }
                "getPendingWidgetAction" -> {
                    val action = pendingWidgetAction
                    pendingWidgetAction = null
                    result.success(action)
                }
                "updateStatsWidget" -> {
                    val total = call.argument<Int>("total") ?: 0
                    val daysRaw = call.argument<List<Int>>("days")
                    val days = IntArray(14)
                    if (daysRaw != null) {
                        for (i in days.indices) {
                            if (i >= daysRaw.size) break
                            days[i] = daysRaw[i]
                        }
                    }
                    val title = call.argument<String>("title") ?: "笔记热力图"
                    val totalLabel = call.argument<String>("totalLabel") ?: "总记录"
                    val rangeLabel = call.argument<String>("rangeLabel") ?: "最近14天"

                    WidgetStatsStore.save(
                        context = this,
                        totalCount = total,
                        days = days,
                        title = title,
                        totalLabel = totalLabel,
                        rangeLabel = rangeLabel,
                    )

                    val appWidgetManager = AppWidgetManager.getInstance(this)
                    val ids = appWidgetManager.getAppWidgetIds(ComponentName(this, StatsWidgetProvider::class.java))
                    StatsWidgetProvider.updateWidgets(this, appWidgetManager, ids)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        pendingWidgetAction?.let { action ->
            pendingWidgetAction = null
            dispatchWidgetAction(action)
        }
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra(WidgetIntents.EXTRA_WIDGET_ACTION)
        if (action.isNullOrBlank()) return
        intent.removeExtra(WidgetIntents.EXTRA_WIDGET_ACTION)
        dispatchWidgetAction(action)
    }

    private fun dispatchWidgetAction(action: String) {
        pendingWidgetAction = action
        val channel = widgetChannel ?: return
        channel.invokeMethod(
            "openWidget",
            mapOf("action" to action),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    pendingWidgetAction = null
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                }

                override fun notImplemented() {
                }
            },
        )
    }
}
