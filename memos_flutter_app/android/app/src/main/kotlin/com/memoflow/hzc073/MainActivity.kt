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
import android.provider.OpenableColumns
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.memoflow.hzc073.widgets.DailyReviewWidgetProvider
import com.memoflow.hzc073.widgets.QuickInputWidgetProvider
import com.memoflow.hzc073.widgets.StatsWidgetProvider
import com.memoflow.hzc073.widgets.WidgetIntents
import com.memoflow.hzc073.widgets.WidgetStatsStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val widgetChannelName = "memoflow/widgets"
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: String? = null
    private val shareChannelName = "memoflow/share"
    private var shareChannel: MethodChannel? = null
    private var pendingSharePayload: SharePayload? = null
    private val ringtoneChannelName = "memoflow/ringtone"
    private var ringtoneChannel: MethodChannel? = null
    private var pendingRingtoneResult: MethodChannel.Result? = null
    private val ringtoneRequestCode = 1001
    private val settingsChannelName = "memoflow/system_settings"
    private var settingsChannel: MethodChannel? = null
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

        val widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannelName)
        this.widgetChannel = widgetChannel
        widgetChannel.setMethodCallHandler { call, result ->
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

        pendingWidgetAction?.let { action ->
            pendingWidgetAction = null
            dispatchWidgetAction(action)
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
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
        val urlInText = if (!text.isNullOrEmpty()) extractFirstUrl(text) else null
        if (!urlInText.isNullOrEmpty()) {
            dispatchShare(SharePayload(type = "text", text = text))
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

        if (!text.isNullOrEmpty()) {
            dispatchShare(SharePayload(type = "text", text = text))
            clearShareIntent(intent)
        }
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

    private data class SharePayload(
        val type: String,
        val text: String? = null,
        val paths: List<String> = emptyList(),
    ) {
        fun toMap(): Map<String, Any?> {
            return mapOf(
                "type" to type,
                "text" to text,
                "paths" to paths,
            )
        }
    }
}
