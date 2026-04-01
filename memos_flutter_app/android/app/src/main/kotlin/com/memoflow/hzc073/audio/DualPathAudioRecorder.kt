package com.memoflow.hzc073.audio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import java.io.File
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min

class QuickSpectrumRecorderException(
    val code: String,
    override val message: String,
    cause: Throwable? = null,
) : Exception(message, cause)

class DualPathAudioRecorder(
    private val context: Context,
    private val onSpectrumFrame: (SpectrumSnapshot) -> Unit,
) {
    companion object {
        private const val mimeType = MediaFormat.MIMETYPE_AUDIO_AAC
        private const val sampleRate = 16_000
        private const val channelCount = 1
        private const val bitRate = 32_000
        private const val bytesPerSample = 2
    }

    private val analyzer = SpectrumAnalyzer(
        sampleRate = sampleRate,
        fftSize = 1024,
        hopSize = 256,
        barCount = 48,
        minFrequency = 60.0,
        maxFrequency = 8_000.0,
    )

    @Volatile
    private var recording = false

    @Volatile
    private var stopRequested = false

    @Volatile
    private var cancelRequested = false

    @Volatile
    private var paused = false

    @Volatile
    private var backgroundError: QuickSpectrumRecorderException? = null

    private val pauseMonitor = Object()

    private var workerThread: Thread? = null
    private var audioRecord: AudioRecord? = null
    private var audioEncoder: MediaCodec? = null
    private var mediaMuxer: MediaMuxer? = null
    private var muxerStarted = false
    private var trackIndex = -1
    private var currentPath: String? = null

    @Synchronized
    fun start(path: String) {
        if (recording) {
            throw QuickSpectrumRecorderException(
                code = "already_recording",
                message = "Quick spectrum recorder is already running.",
            )
        }

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            throw QuickSpectrumRecorderException(
                code = "no_permission",
                message = "Microphone permission is required.",
            )
        }

        val outputFile = File(path)
        val parent = outputFile.parentFile
        if (path.isBlank() || (parent != null && !parent.exists() && !parent.mkdirs())) {
            throw QuickSpectrumRecorderException(
                code = "invalid_path",
                message = "Invalid recording output path.",
            )
        }

        if (outputFile.exists()) {
            outputFile.delete()
        }

        val minBufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBufferSize <= 0) {
            throw QuickSpectrumRecorderException(
                code = "recorder_init_failed",
                message = "Unable to determine recorder buffer size.",
            )
        }

        val recordBufferSize = max(minBufferSize * 2, 4096)

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                recordBufferSize,
            ).also {
                if (it.state != AudioRecord.STATE_INITIALIZED) {
                    throw QuickSpectrumRecorderException(
                        code = "recorder_init_failed",
                        message = "Failed to initialize AudioRecord.",
                    )
                }
            }

            audioEncoder = MediaCodec.createEncoderByType(mimeType).also { codec ->
                val format = MediaFormat.createAudioFormat(mimeType, sampleRate, channelCount).apply {
                    setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                    setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                    setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, recordBufferSize)
                }
                codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                codec.start()
            }

            mediaMuxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        } catch (error: QuickSpectrumRecorderException) {
            releaseResources(deleteOutput = true)
            throw error
        } catch (error: Exception) {
            releaseResources(deleteOutput = true)
            throw QuickSpectrumRecorderException(
                code = "encoder_init_failed",
                message = "Failed to initialize quick spectrum recorder.",
                cause = error,
            )
        }

        currentPath = path
        backgroundError = null
        analyzer.reset()
        stopRequested = false
        cancelRequested = false
        paused = false
        muxerStarted = false
        trackIndex = -1
        recording = true

        workerThread = Thread(
            {
                captureLoop(recordBufferSize)
            },
            "QuickSpectrumRecorder",
        ).also { it.start() }
    }

    @Synchronized
    fun stop(): String? {
        if (!recording) {
            return currentPath
        }

        stopRequested = true
        joinWorkerThread()
        backgroundError?.let { throw it }
        return currentPath
    }

    @Synchronized
    fun cancel() {
        if (!recording) {
            currentPath?.let { File(it).delete() }
            currentPath = null
            return
        }

        cancelRequested = true
        stopRequested = true
        joinWorkerThread()
        currentPath = null
    }

    @Synchronized
    fun pause() {
        if (!recording || paused) {
            return
        }
        paused = true
        try {
            audioRecord?.stop()
        } catch (_: Exception) {
        }
    }

    @Synchronized
    fun resume() {
        if (!recording || !paused) {
            return
        }
        paused = false
        synchronized(pauseMonitor) {
            pauseMonitor.notifyAll()
        }
    }

    @Synchronized
    fun dispose() {
        if (recording) {
            try {
                cancel()
            } catch (_: Exception) {
            }
        } else {
            releaseResources(deleteOutput = false)
        }
    }

    private fun captureLoop(recordBufferSize: Int) {
        val localRecord = audioRecord ?: return
        val localEncoder = audioEncoder ?: return
        val localMuxer = mediaMuxer ?: return
        val bufferInfo = MediaCodec.BufferInfo()
        val readBuffer = ByteArray(recordBufferSize)
        var totalSamples = 0L

        try {
            localRecord.startRecording()
            if (localRecord.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                throw QuickSpectrumRecorderException(
                    code = "recorder_init_failed",
                    message = "AudioRecord failed to start.",
                )
            }

            while (!stopRequested) {
                if (paused) {
                    synchronized(pauseMonitor) {
                        while (paused && !stopRequested) {
                            pauseMonitor.wait(100)
                        }
                    }
                    if (stopRequested) {
                        break
                    }
                    localRecord.startRecording()
                    if (localRecord.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                        throw QuickSpectrumRecorderException(
                            code = "recorder_init_failed",
                            message = "AudioRecord failed to resume.",
                        )
                    }
                    continue
                }

                val read = localRecord.read(readBuffer, 0, readBuffer.size)
                when {
                    read > 0 -> {
                        analyzer.processPcm(readBuffer, read, onSpectrumFrame)
                        totalSamples = queuePcmToEncoder(localEncoder, localMuxer, bufferInfo, readBuffer, read, totalSamples)
                        drainEncoder(localEncoder, localMuxer, bufferInfo, endOfStream = false)
                    }

                    read == 0 -> Unit

                    paused && read == AudioRecord.ERROR_INVALID_OPERATION -> Unit

                    else -> {
                        throw QuickSpectrumRecorderException(
                            code = "recorder_init_failed",
                            message = "AudioRecord read failed: $read",
                        )
                    }
                }
            }

            queueEndOfStream(localEncoder, totalSamples)
            drainEncoder(localEncoder, localMuxer, bufferInfo, endOfStream = true)
        } catch (error: QuickSpectrumRecorderException) {
            backgroundError = error
        } catch (error: Exception) {
            backgroundError = QuickSpectrumRecorderException(
                code = "recorder_init_failed",
                message = "Quick spectrum recording failed.",
                cause = error,
            )
        } finally {
            releaseResources(deleteOutput = cancelRequested || backgroundError != null)
            recording = false
            stopRequested = false
            cancelRequested = false
            paused = false
            workerThread = null
        }
    }

    private fun joinWorkerThread() {
        val thread = workerThread ?: return
        thread.join(4000)
        if (thread.isAlive) {
            throw QuickSpectrumRecorderException(
                code = "recorder_init_failed",
                message = "Quick spectrum recorder did not stop in time.",
            )
        }
    }

    private fun queuePcmToEncoder(
        encoder: MediaCodec,
        muxer: MediaMuxer,
        bufferInfo: MediaCodec.BufferInfo,
        buffer: ByteArray,
        length: Int,
        initialSamplePosition: Long,
    ): Long {
        var offset = 0
        var samplePosition = initialSamplePosition

        while (offset < length) {
            val inputIndex = encoder.dequeueInputBuffer(10_000)
            if (inputIndex >= 0) {
                val inputBuffer = encoder.getInputBuffer(inputIndex)
                    ?: throw QuickSpectrumRecorderException(
                        code = "encoder_init_failed",
                        message = "Encoder input buffer is unavailable.",
                    )
                inputBuffer.clear()
                val bytesToWrite = min(inputBuffer.remaining(), length - offset)
                inputBuffer.put(buffer, offset, bytesToWrite)
                val presentationTimeUs = samplePosition * 1_000_000L / sampleRate
                encoder.queueInputBuffer(inputIndex, 0, bytesToWrite, presentationTimeUs, 0)
                offset += bytesToWrite
                samplePosition += bytesToWrite / bytesPerSample
            } else {
                drainEncoder(encoder, muxer, bufferInfo, endOfStream = false)
            }
        }

        return samplePosition
    }

    private fun queueEndOfStream(encoder: MediaCodec, totalSamples: Long) {
        while (true) {
            val inputIndex = encoder.dequeueInputBuffer(10_000)
            if (inputIndex >= 0) {
                val presentationTimeUs = totalSamples * 1_000_000L / sampleRate
                encoder.queueInputBuffer(
                    inputIndex,
                    0,
                    0,
                    presentationTimeUs,
                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                )
                return
            }
        }
    }

    private fun drainEncoder(
        encoder: MediaCodec,
        muxer: MediaMuxer,
        bufferInfo: MediaCodec.BufferInfo,
        endOfStream: Boolean,
    ) {
        while (true) {
            val outputIndex = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) {
                        return
                    }
                }

                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (muxerStarted) {
                        throw QuickSpectrumRecorderException(
                            code = "muxer_init_failed",
                            message = "Output format changed twice.",
                        )
                    }
                    trackIndex = muxer.addTrack(encoder.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }

                outputIndex >= 0 -> {
                    val outputBuffer = encoder.getOutputBuffer(outputIndex)
                        ?: throw QuickSpectrumRecorderException(
                            code = "encoder_init_failed",
                            message = "Encoder output buffer is unavailable.",
                        )

                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                        bufferInfo.size = 0
                    }

                    if (bufferInfo.size > 0) {
                        if (!muxerStarted || trackIndex < 0) {
                            throw QuickSpectrumRecorderException(
                                code = "muxer_init_failed",
                                message = "Muxer is not ready for encoded output.",
                            )
                        }
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(trackIndex, outputBuffer, bufferInfo)
                    }

                    encoder.releaseOutputBuffer(outputIndex, false)

                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        return
                    }
                }
            }
        }
    }

    private fun releaseResources(deleteOutput: Boolean) {
        val path = currentPath

        val localRecord = audioRecord
        audioRecord = null
        try {
            if (localRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                localRecord.stop()
            }
        } catch (_: Exception) {
        }
        localRecord?.release()

        val localEncoder = audioEncoder
        audioEncoder = null
        try {
            localEncoder?.stop()
        } catch (_: Exception) {
        }
        try {
            localEncoder?.release()
        } catch (_: Exception) {
        }

        val localMuxer = mediaMuxer
        mediaMuxer = null
        try {
            if (muxerStarted) {
                localMuxer?.stop()
            }
        } catch (_: Exception) {
        }
        try {
            localMuxer?.release()
        } catch (_: Exception) {
        }

        muxerStarted = false
        trackIndex = -1

        if (deleteOutput && !path.isNullOrBlank()) {
            File(path).delete()
        }
    }
}
