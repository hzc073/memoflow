package com.memoflow.hzc073.audio

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class QuickSpectrumRecorderChannel(
    context: Context,
    messenger: BinaryMessenger,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val operationExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val methodChannel = MethodChannel(messenger, methodChannelName)
    private val eventChannel = EventChannel(messenger, eventChannelName)
    private val frameSequence = AtomicInteger(0)

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    private val recorder = DualPathAudioRecorder(context.applicationContext) { snapshot ->
        dispatchFrame(snapshot)
    }

    init {
        methodChannel.setMethodCallHandler(::handleMethodCall)
        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        operationExecutor.execute {
            recorder.dispose()
        }
        operationExecutor.shutdown()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val path = call.argument<String>("path")?.trim().orEmpty()
                if (path.isEmpty()) {
                    result.error("invalid_path", "Invalid recording output path.", null)
                    return
                }
                frameSequence.set(0)
                operationExecutor.execute {
                    runCatching {
                        recorder.start(path)
                    }.onSuccess {
                        result.success(null)
                    }.onFailure {
                        reportError(result, it)
                    }
                }
            }

            "stop" -> {
                operationExecutor.execute {
                    runCatching {
                        recorder.stop()
                    }.onSuccess { path ->
                        result.success(path)
                    }.onFailure {
                        reportError(result, it)
                    }
                }
            }

            "pause" -> {
                operationExecutor.execute {
                    runCatching {
                        recorder.pause()
                    }.onSuccess {
                        result.success(null)
                    }.onFailure {
                        reportError(result, it)
                    }
                }
            }

            "resume" -> {
                operationExecutor.execute {
                    runCatching {
                        recorder.resume()
                    }.onSuccess {
                        result.success(null)
                    }.onFailure {
                        reportError(result, it)
                    }
                }
            }

            "cancel" -> {
                operationExecutor.execute {
                    runCatching {
                        recorder.cancel()
                    }.onSuccess {
                        result.success(null)
                    }.onFailure {
                        reportError(result, it)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun reportError(result: MethodChannel.Result, throwable: Throwable) {
        val quickError = throwable as? QuickSpectrumRecorderException
        if (quickError != null) {
            result.error(quickError.code, quickError.message, null)
            return
        }
        result.error("recorder_init_failed", throwable.message, null)
    }

    private fun dispatchFrame(snapshot: SpectrumSnapshot) {
        val sink = eventSink ?: return
        val sequence = frameSequence.getAndIncrement()
        val payload = hashMapOf<String, Any>(
            "bars" to snapshot.bars,
            "rmsLevel" to snapshot.rmsLevel,
            "peakLevel" to snapshot.peakLevel,
            "hasVoice" to snapshot.hasVoice,
            "sequence" to sequence,
        )
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private companion object {
        const val methodChannelName = "memoflow/quick_spectrum_recorder"
        const val eventChannelName = "memoflow/quick_spectrum_recorder/frames"
    }
}
