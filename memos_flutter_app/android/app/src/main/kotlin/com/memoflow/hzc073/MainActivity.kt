package com.memoflow.hzc073

import android.app.Activity
import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.database.Cursor
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.SystemClock
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.memoflow.hzc073.audio.QuickSpectrumRecorderChannel
import com.memoflow.hzc073.widgets.DailyReviewWidgetProvider
import com.memoflow.hzc073.widgets.QuickInputWidgetProvider
import com.memoflow.hzc073.widgets.StatsWidgetProvider
import com.memoflow.hzc073.widgets.WidgetCalendarDay
import com.memoflow.hzc073.widgets.WidgetCalendarHeatScore
import com.memoflow.hzc073.widgets.WidgetCalendarStore
import com.memoflow.hzc073.widgets.WidgetDailyReviewItem
import com.memoflow.hzc073.widgets.WidgetDailyReviewStore
import com.memoflow.hzc073.widgets.WidgetIntents
import com.memoflow.hzc073.widgets.WidgetQuickInputStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val startupTag = "StartupTiming"
    private val widgetChannelName = "memoflow/widgets"
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetLaunch: Map<String, Any?>? = null
    private val shareChannelName = "memoflow/share"
    private var shareChannel: MethodChannel? = null
    private var pendingSharePayload: SharePayload? = null
    private val ringtoneChannelName = "memoflow/ringtone"
    private var ringtoneChannel: MethodChannel? = null
    private var pendingRingtoneResult: MethodChannel.Result? = null
    private val ringtoneRequestCode = 1001
    private val settingsChannelName = "memoflow/system_settings"
    private var settingsChannel: MethodChannel? = null
    private var quickSpectrumRecorderChannel: QuickSpectrumRecorderChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        logStartup("MainActivity.onCreate")
        logStartup("android_splash_shown")
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        logStartup("MainActivity.onFlutterUiDisplayed")
        logStartup("android_splash_exit")
    }

    override fun onFlutterUiNoLongerDisplayed() {
        super.onFlutterUiNoLongerDisplayed()
        logStartup("MainActivity.onFlutterUiNoLongerDisplayed")
    }

    private fun logStartup(event: String) {
        val epochMs = System.currentTimeMillis()
        val uptimeMs = SystemClock.uptimeMillis()
        Log.i(startupTag, "$event epochMs=$epochMs uptimeMs=$uptimeMs")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        quickSpectrumRecorderChannel = QuickSpectrumRecorderChannel(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )

        val widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannelName)
        this.widgetChannel = widgetChannel
        widgetChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPinWidget" -> {
                    val type = WidgetIntents.normalizeAction(call.argument<String>("type"))
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
                        WidgetIntents.ACTION_DAILY_REVIEW -> ComponentName(this, DailyReviewWidgetProvider::class.java)
                        WidgetIntents.ACTION_QUICK_INPUT -> ComponentName(this, QuickInputWidgetProvider::class.java)
                        WidgetIntents.ACTION_CALENDAR -> ComponentName(this, StatsWidgetProvider::class.java)
                        else -> null
                    }

                    if (provider == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    appWidgetManager.requestPinAppWidget(provider, null, null)
                    result.success(true)
                }
                "getPendingWidgetLaunch" -> {
                    val payload = pendingWidgetLaunch
                    pendingWidgetLaunch = null
                    result.success(payload)
                }
                "getPendingWidgetAction" -> {
                    val action = pendingWidgetLaunch?.get("widgetType") as? String
                    pendingWidgetLaunch = null
                    result.success(action)
                }
                "updateDailyReviewWidget" -> {
                    val title =
                        call.argument<String>("title")
                            ?.trim()
                            .takeUnless { it.isNullOrEmpty() }
                            ?: getString(R.string.widget_daily_review_placeholder_title)
                    val fallbackBody =
                        call.argument<String>("fallbackBody")
                            ?.trim()
                            .takeUnless { it.isNullOrEmpty() }
                            ?: getString(R.string.widget_daily_review_placeholder_body)
                    val items = parseDailyReviewItems(call.argument<List<*>>("items"))
                    val avatarBytes = call.argument<ByteArray>("avatarBytes")
                    val clearAvatar = call.argument<Boolean>("clearAvatar") ?: false
                    val localeTag = call.argument<String>("localeTag")?.trim().orEmpty()
                    WidgetDailyReviewStore.save(
                        context = this,
                        title = title,
                        fallbackBody = fallbackBody,
                        items = items,
                        avatarBytes = avatarBytes,
                        clearAvatar = clearAvatar,
                        localeTag = localeTag,
                    )
                    DailyReviewWidgetProvider.updateAllWidgets(this)
                    DailyReviewWidgetProvider.ensureRotation(this)
                    result.success(true)
                }
                "updateQuickInputWidget" -> {
                    val hint =
                        call.argument<String>("hint")
                            ?.trim()
                            .takeUnless { it.isNullOrEmpty() }
                            ?: getString(R.string.widget_quick_input_hint)
                    WidgetQuickInputStore.save(this, hint)
                    QuickInputWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                "advanceDailyReviewWidget" -> {
                    WidgetDailyReviewStore.advance(this)
                    DailyReviewWidgetProvider.updateAllWidgets(this)
                    DailyReviewWidgetProvider.ensureRotation(this)
                    result.success(true)
                }
                "updateCalendarWidget" -> {
                    val monthLabel =
                        call.argument<String>("monthLabel")
                            ?.trim()
                            .takeUnless { it.isNullOrEmpty() }
                            ?: getString(R.string.widget_calendar_placeholder_title)
                    val weekdayLabels = parseStringList(call.argument<List<*>>("weekdayLabels"))
                    val days = parseCalendarDays(call.argument<List<*>>("days"))
                    val monthStartEpochSec = call.argument<Number>("monthStartEpochSec")?.toLong()
                    val localeTag = call.argument<String>("localeTag")?.trim().orEmpty()
                    val mondayFirst = call.argument<Boolean>("mondayFirst") ?: false
                    val heatScores = parseCalendarHeatScores(call.argument<List<*>>("heatScores"))
                    val themeColorArgb =
                        call.argument<Number>("themeColorArgb")?.toLong()?.toInt()
                            ?: 0xFFB85C52.toInt()
                    Log.d(
                        startupTag,
                        "updateCalendarWidget monthLabel=$monthLabel weekdays=${weekdayLabels.size} days=${days.size} heatScores=${heatScores.size} monthStartEpochSec=$monthStartEpochSec localeTag=$localeTag mondayFirst=$mondayFirst themeColorArgb=$themeColorArgb",
                    )
                    WidgetCalendarStore.save(
                        context = this,
                        monthLabel = monthLabel,
                        weekdayLabels = weekdayLabels,
                        days = days,
                        monthStartEpochSec = monthStartEpochSec,
                        localeTag = localeTag,
                        mondayFirst = mondayFirst,
                        heatScores = heatScores,
                        themeColorArgb = themeColorArgb,
                    )
                    StatsWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                "updateStatsWidget" -> {
                    result.success(false)
                }
                "moveTaskToBack" -> {
                    result.success(moveTaskToBack(true))
                }
                "clearHomeWidgets" -> {
                    WidgetDailyReviewStore.clear(this)
                    WidgetQuickInputStore.clear(this)
                    WidgetCalendarStore.clear(this)
                    DailyReviewWidgetProvider.updateAllWidgets(this)
                    DailyReviewWidgetProvider.cancelRotation(this)
                    QuickInputWidgetProvider.updateAllWidgets(this)
                    StatsWidgetProvider.updateAllWidgets(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
        this.shareChannel = shareChannel
        shareChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingShare" -> {
                    val payload = pendingSharePayload
                    pendingSharePayload = null
                    result.success(payload?.toMap())
                }
                else -> result.notImplemented()
            }
        }

        val ringtoneChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ringtoneChannelName)
        this.ringtoneChannel = ringtoneChannel
        ringtoneChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickRingtone" -> {
                    if (pendingRingtoneResult != null) {
                        result.error("PICKING", "Ringtone picker already active", null)
                        return@setMethodCallHandler
                    }
                    val currentUri = call.argument<String>("currentUri")?.trim()
                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI, Settings.System.DEFAULT_NOTIFICATION_URI)
                        if (!currentUri.isNullOrBlank()) {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(currentUri))
                        }
                    }
                    pendingRingtoneResult = result
                    startActivityForResult(intent, ringtoneRequestCode)
                }
                else -> result.notImplemented()
            }
        }

        val settingsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, settingsChannelName)
        this.settingsChannel = settingsChannel
        settingsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppSettings" -> result.success(openAppSettings())
                "openNotificationSettings" -> result.success(openNotificationSettings())
                "openNotificationChannelSettings" -> {
                    val channelId = call.argument<String>("channelId")
                    result.success(openNotificationChannelSettings(channelId))
                }
                "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())
                "requestExactAlarmsPermission" -> result.success(requestExactAlarmsPermission())
                "openExactAlarmSettings" -> result.success(openExactAlarmSettings())
                "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                "requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBatteryOptimizations())
                "openBatteryOptimizationSettings" -> result.success(openBatteryOptimizationSettings())
                else -> result.notImplemented()
            }
        }

        pendingWidgetLaunch?.let { payload ->
            pendingWidgetLaunch = null
            dispatchWidgetLaunch(payload)
        }
        pendingSharePayload?.let { payload ->
            pendingSharePayload = null
            dispatchShare(payload)
        }
        handleWidgetIntent(intent)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent(intent)
        handleShareIntent(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ringtoneRequestCode) return
        val pending = pendingRingtoneResult ?: return
        pendingRingtoneResult = null
        if (resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return
        }
        val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        if (uri == null) {
            pending.success(
                mapOf(
                    "isSilent" to true,
                    "isDefault" to false,
                ),
            )
            return
        }
        val title = RingtoneManager.getRingtone(this, uri)?.getTitle(this) ?: ""
        val isDefault = uri == Settings.System.DEFAULT_NOTIFICATION_URI
        pending.success(
            mapOf(
                "uri" to uri.toString(),
                "title" to title,
                "isSilent" to false,
                "isDefault" to isDefault,
            ),
        )
    }

    private fun handleWidgetIntent(intent: Intent?) {
        if (intent == null) return
        val action = WidgetIntents.normalizeAction(intent.getStringExtra(WidgetIntents.EXTRA_WIDGET_ACTION)) ?: return
        val memoUid = intent.getStringExtra(WidgetIntents.EXTRA_MEMO_UID)?.trim()?.takeIf { it.isNotEmpty() }
        val dayEpochSec = if (intent.hasExtra(WidgetIntents.EXTRA_DAY_EPOCH_SEC)) {
            intent.getLongExtra(WidgetIntents.EXTRA_DAY_EPOCH_SEC, 0L).takeIf { it > 0L }
        } else {
            null
        }
        Log.d(
            startupTag,
            "handleWidgetIntent action=$action memoUid=$memoUid dayEpochSec=$dayEpochSec rawAction=${intent.action}",
        )
        intent.removeExtra(WidgetIntents.EXTRA_WIDGET_ACTION)
        intent.removeExtra(WidgetIntents.EXTRA_MEMO_UID)
        intent.removeExtra(WidgetIntents.EXTRA_DAY_EPOCH_SEC)
        dispatchWidgetLaunch(buildWidgetLaunchPayload(action, memoUid, dayEpochSec))
    }

    private fun dispatchWidgetLaunch(payload: Map<String, Any?>) {
        pendingWidgetLaunch = payload
        val channel = widgetChannel ?: return
        channel.invokeMethod(
            "openWidget",
            payload,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    pendingWidgetLaunch = null
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                }

                override fun notImplemented() {
                }
            },
        )
    }

    private fun buildWidgetLaunchPayload(
        action: String,
        memoUid: String? = null,
        dayEpochSec: Long? = null,
    ): Map<String, Any?> {
        val payload = mutableMapOf<String, Any?>("widgetType" to action)
        if (!memoUid.isNullOrBlank()) {
            payload["memoUid"] = memoUid
        }
        if (dayEpochSec != null && dayEpochSec > 0L) {
            payload["dayEpochSec"] = dayEpochSec
        }
        return payload
    }

    private fun parseStringList(raw: List<*>?): List<String> {
        if (raw == null) return emptyList()
        return raw.mapNotNull { item -> item?.toString()?.takeIf { it.isNotBlank() } }
    }

    private fun parseDailyReviewItems(raw: List<*>?): List<WidgetDailyReviewItem> {
        if (raw == null) return emptyList()
        return raw.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val excerpt = map["excerpt"]?.toString()?.trim().orEmpty()
            if (excerpt.isEmpty()) return@mapNotNull null
            WidgetDailyReviewItem(
                memoUid = map["memoUid"]?.toString()?.trim()?.takeIf { it.isNotEmpty() },
                excerpt = excerpt,
                dateLabel = map["dateLabel"]?.toString()?.trim().orEmpty(),
            )
        }
    }

    private fun parseCalendarDays(raw: List<*>?): List<WidgetCalendarDay> {
        if (raw == null) return emptyList()
        return raw.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val intensity = when (val value = map["intensity"]) {
                is Int -> value
                is Number -> value.toInt()
                is String -> value.trim().toIntOrNull() ?: 0
                else -> 0
            }.coerceIn(0, 6)
            val dayEpochSec = when (val value = map["dayEpochSec"]) {
                is Long -> value
                is Int -> value.toLong()
                is Number -> value.toLong()
                is String -> value.trim().toLongOrNull()
                else -> null
            }
            WidgetCalendarDay(
                label = map["label"]?.toString().orEmpty(),
                intensity = intensity,
                dayEpochSec = dayEpochSec,
                isCurrentMonth = when (val value = map["isCurrentMonth"]) {
                    is Boolean -> value
                    is String -> value.equals("true", ignoreCase = true)
                    else -> false
                },
                isToday = when (val value = map["isToday"]) {
                    is Boolean -> value
                    is String -> value.equals("true", ignoreCase = true)
                    else -> false
                },
            )
        }
    }

    override fun onDestroy() {
        quickSpectrumRecorderChannel?.dispose()
        quickSpectrumRecorderChannel = null
        super.onDestroy()
    }

    private fun parseCalendarHeatScores(raw: List<*>?): List<WidgetCalendarHeatScore> {
        if (raw == null) return emptyList()
        return raw.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val dayEpochSec = when (val value = map["dayEpochSec"]) {
                is Long -> value
                is Int -> value.toLong()
                is Number -> value.toLong()
                is String -> value.trim().toLongOrNull()
                else -> null
            } ?: return@mapNotNull null
            val heatScore = when (val value = map["heatScore"]) {
                is Int -> value
                is Number -> value.toInt()
                is String -> value.trim().toIntOrNull() ?: 0
                else -> 0
            }.coerceAtLeast(0)
            WidgetCalendarHeatScore(dayEpochSec = dayEpochSec, heatScore = heatScore)
        }
    }

    private fun dispatchShare(payload: SharePayload) {
        pendingSharePayload = payload
        val channel = shareChannel ?: return
        channel.invokeMethod(
            "openShare",
            payload.toMap(),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    pendingSharePayload = null
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                }

                override fun notImplemented() {
                }
            },
        )
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        if (
            action != Intent.ACTION_SEND &&
            action != Intent.ACTION_SEND_MULTIPLE &&
            action != Intent.ACTION_PROCESS_TEXT
        ) {
            return
        }

        if (action == Intent.ACTION_PROCESS_TEXT) {
            val processText = extractProcessText(intent)
            if (!processText.isNullOrEmpty()) {
                dispatchShare(
                    SharePayload(
                        type = "text",
                        handlingMode = SHARE_HANDLING_MODE_QUICK_RECORD,
                        text = processText,
                        title = extractShareTitle(intent, processText, null),
                    ),
                )
            }
            clearShareIntent(intent)
            return
        }

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
        val urlInText = if (!text.isNullOrEmpty()) extractFirstUrl(text) else null
        val title = extractShareTitle(intent, text, urlInText)
        if (!urlInText.isNullOrEmpty()) {
            dispatchShare(SharePayload(type = "text", text = text, title = title))
            clearShareIntent(intent)
            return
        }

        val sharedUris = extractShareUris(intent)
        if (sharedUris.isNotEmpty()) {
            val paths = sharedUris.mapNotNull { cacheShareUri(it) }
            if (paths.isNotEmpty()) {
                dispatchShare(SharePayload(type = "images", paths = paths))
            }
            clearShareIntent(intent)
            return
        }

        val clipText = if (text.isNullOrEmpty()) extractPlainClipText(intent) else null
        if (!clipText.isNullOrEmpty()) {
            dispatchShare(
                SharePayload(
                    type = "text",
                    handlingMode = SHARE_HANDLING_MODE_QUICK_RECORD,
                    text = clipText,
                    title = extractShareTitle(intent, clipText, null),
                ),
            )
            clearShareIntent(intent)
            return
        }

        if (!text.isNullOrEmpty()) {
            dispatchShare(SharePayload(type = "text", text = text, title = title))
            clearShareIntent(intent)
        }
    }

    private fun extractProcessText(intent: Intent): String? {
        val value = intent.extras?.getCharSequence(Intent.EXTRA_PROCESS_TEXT)
            ?: intent.getStringExtra(Intent.EXTRA_PROCESS_TEXT)
        return value?.toString()?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun extractPlainClipText(intent: Intent): String? {
        val clip = intent.clipData ?: return null
        val result = mutableListOf<String>()
        for (i in 0 until clip.itemCount) {
            val item = clip.getItemAt(i)
            if (item.uri != null || item.intent != null) {
                return null
            }
            val text = item.text?.toString()
                ?: item.htmlText?.toString()
            val normalized = text?.trim().orEmpty()
            if (normalized.isNotEmpty()) {
                result.add(normalized)
            }
        }
        return result
            .joinToString(separator = "\n")
            .trim()
            .takeIf { it.isNotEmpty() }
    }

    private fun extractShareTitle(intent: Intent, text: String?, sharedUrl: String?): String? {
        val explicitTitle = sequenceOf(
            intent.getStringExtra(Intent.EXTRA_SUBJECT),
            intent.getStringExtra(Intent.EXTRA_TITLE),
            intent.extras?.getCharSequence(Intent.EXTRA_SUBJECT)?.toString(),
            intent.extras?.getCharSequence(Intent.EXTRA_TITLE)?.toString(),
        )
            .mapNotNull { normalizeShareTitle(it) }
            .firstOrNull()
        if (!explicitTitle.isNullOrEmpty()) {
            return explicitTitle
        }

        if (text.isNullOrBlank()) return null
        val derivedTitle = if (sharedUrl.isNullOrEmpty()) {
            text
        } else {
            text.replaceFirst(sharedUrl, " ")
        }
        return normalizeShareTitle(derivedTitle)
    }

    private fun extractShareUris(intent: Intent): List<Uri> {
        val result = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> {
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { result.add(it) }
                val clip = intent.clipData
                if (clip != null) {
                    for (i in 0 until clip.itemCount) {
                        clip.getItemAt(i).uri?.let { result.add(it) }
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val streams = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                if (streams != null) {
                    result.addAll(streams)
                }
                val clip = intent.clipData
                if (clip != null) {
                    for (i in 0 until clip.itemCount) {
                        clip.getItemAt(i).uri?.let { result.add(it) }
                    }
                }
            }
        }
        return result.distinctBy { it.toString() }
    }

    private fun cacheShareUri(uri: Uri): String? {
        val scheme = uri.scheme?.lowercase() ?: ""
        if (scheme == "file") {
            val path = uri.path
            if (!path.isNullOrBlank()) return path
        }

        return try {
            val resolver = contentResolver
            val displayName = queryDisplayName(uri)
            val mimeType = resolver.getType(uri)
            val extension = resolveExtension(displayName, mimeType)
            val baseName = sanitizeFileName(displayName ?: "share_${System.currentTimeMillis()}")
            val filename = if (extension.isNotBlank() && !baseName.endsWith(".$extension")) {
                "$baseName.$extension"
            } else {
                baseName
            }
            val target = File(cacheDir, "share_${System.currentTimeMillis()}_$filename")
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output ->
                    input.copyTo(output)
                }
            }
            if (target.exists()) target.absolutePath else null
        } catch (_: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            } else {
                null
            }
        } catch (_: Exception) {
            null
        } finally {
            cursor?.close()
        }
    }

    private fun resolveExtension(displayName: String?, mimeType: String?): String {
        if (!displayName.isNullOrBlank()) {
            val dotIndex = displayName.lastIndexOf('.')
            if (dotIndex in 1 until displayName.length - 1) {
                return displayName.substring(dotIndex + 1)
            }
        }
        if (!mimeType.isNullOrBlank()) {
            return MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType) ?: ""
        }
        return ""
    }

    private fun sanitizeFileName(name: String): String {
        return name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
    }

    private fun clearShareIntent(intent: Intent) {
        intent.removeExtra(Intent.EXTRA_TEXT)
        intent.removeExtra(Intent.EXTRA_PROCESS_TEXT)
        intent.removeExtra(Intent.EXTRA_SUBJECT)
        intent.removeExtra(Intent.EXTRA_TITLE)
        intent.removeExtra(Intent.EXTRA_STREAM)
        intent.clipData = null
    }

    private fun openAppSettings(): Boolean {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
        return startActivitySafe(intent)
    }

    private fun openNotificationSettings(): Boolean {
        val opened = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            startActivitySafe(intent)
        } else {
            val intent = Intent("android.settings.APP_NOTIFICATION_SETTINGS").apply {
                putExtra("app_package", packageName)
                putExtra("app_uid", applicationInfo.uid)
            }
            startActivitySafe(intent)
        }
        return opened || openAppSettings()
    }

    private fun openNotificationChannelSettings(channelId: String?): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return openNotificationSettings()
        }
        if (channelId.isNullOrBlank()) {
            return openNotificationSettings()
        }
        val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
        }
        return startActivitySafe(intent) || openNotificationSettings()
    }

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return openAppSettings()
        }
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:$packageName")
        }
        return startActivitySafe(intent) || openAppSettings()
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = getSystemService(AlarmManager::class.java)
        return alarmManager.canScheduleExactAlarms()
    }

    private fun requestExactAlarmsPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
            data = Uri.parse("package:$packageName")
        }
        return startActivitySafe(intent)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = getSystemService(PowerManager::class.java)
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        return startActivitySafe(intent)
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        return startActivitySafe(intent) || openAppSettings()
    }

    private fun startActivitySafe(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun extractFirstUrl(raw: String): String? {
        val match = Regex("https?://\\S+").find(raw) ?: return null
        return match.value
    }

    private fun normalizeShareTitle(value: String?): String? {
        if (value.isNullOrBlank()) return null
        val normalized = value.replace(Regex("\\s+"), " ").trim()
        if (normalized.isBlank()) return null
        if (Regex("^https?://\\S+$", RegexOption.IGNORE_CASE).matches(normalized)) {
            return null
        }
        return normalized
    }

    private data class SharePayload(
        val type: String,
        val handlingMode: String = SHARE_HANDLING_MODE_STANDARD_SHARE,
        val text: String? = null,
        val title: String? = null,
        val paths: List<String> = emptyList(),
    ) {
        fun toMap(): Map<String, Any?> {
            return mapOf(
                "type" to type,
                "handlingMode" to handlingMode,
                "text" to text,
                "title" to title,
                "paths" to paths,
            )
        }
    }

    companion object {
        private const val SHARE_HANDLING_MODE_STANDARD_SHARE = "standardShare"
        private const val SHARE_HANDLING_MODE_QUICK_RECORD = "quickRecord"
    }
}
