package org.miarina.media

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Technical details and pictures of a media file read by Android
 * (MediaMetadataRetriever), where FFmpeg does not run: duration, picture
 * size, codecs, audio quality, embedded cover or a representative video
 * frame. Ported from MediaToolsPlugin of the Tauri app; read only.
 */
class MediaProbeChannel(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
  private val channel = MethodChannel(messenger, "org.miarina.media/media_probe")
  private val worker = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())

  init {
    channel.setMethodCallHandler(this)
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    worker.shutdownNow()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "probe") {
      result.notImplemented()
      return
    }
    val path = call.argument<String>("path")
    if (path == null) {
      result.error("args", "path missing", null)
      return
    }
    val thumbnail = call.argument<String>("thumbnail")
    val maxPx = call.argument<Int>("maxPx") ?: 360
    worker.execute {
      val reply = try {
        read(path, thumbnail, maxPx)
      } catch (e: Exception) {
        null
      }
      main.post { result.success(reply) }
    }
  }

  private fun read(path: String, thumbnail: String?, maxPx: Int): Map<String, Any?> {
    val retriever = MediaMetadataRetriever()
    try {
      retriever.setDataSource(path)
      val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
      val hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes"
      var width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
      var height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
      val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
      if (rotation == 90 || rotation == 270) {
        width = height.also { height = width }
      }
      val (videoCodec, audioCodec, sampleRate) = codecs(path)
      val bitRate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toLongOrNull()
      val bits = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITS_PER_SAMPLE)?.toIntOrNull()
      } else {
        null
      }

      var written = false
      if (thumbnail != null) {
        val picture = if (hasVideo) frame(retriever, durationMs, maxPx) else cover(retriever, maxPx)
        if (picture != null) written = writeJpeg(picture, File(thumbnail))
      }

      return mapOf(
        "durationSecs" to durationMs?.let { it / 1000.0 },
        "width" to if (hasVideo) width else null,
        "height" to if (hasVideo) height else null,
        "videoCodec" to videoCodec,
        "audioCodec" to audioCodec,
        "container" to container(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)),
        "hasVideo" to hasVideo,
        "sampleRate" to sampleRate,
        // Bits per sample only means something for lossless and PCM audio.
        "bitDepth" to if (audioCodec in LOSSLESS) bits?.takeIf { it > 0 } else null,
        "bitRate" to bitRate?.let { (it / 1000).toInt() }?.takeIf { it > 0 },
        "thumbnailWritten" to written,
      )
    } finally {
      retriever.release()
    }
  }

  /**
   * A representative frame, longest edge <= maxPx. Tries 10 %, 25 % and 50 %
   * into the video (at most 30 s for the first) and keeps the first that is
   * not almost black (title cards, fades), or else the brightest one.
   */
  private fun frame(retriever: MediaMetadataRetriever, durationMs: Long?, maxPx: Int): Bitmap? {
    val total = durationMs ?: 10_000L
    val candidates = listOf((total / 10).coerceAtMost(30_000L), total / 4, total / 2)
    var best: Bitmap? = null
    var bestLight = -1.0
    for (atMs in candidates.distinct()) {
      val bitmap = grab(retriever, atMs * 1000, maxPx) ?: continue
      val light = brightness(bitmap)
      if (light > bestLight) {
        best = bitmap
        bestLight = light
      }
      if (light >= DARK_FRAME) break
    }
    return best
  }

  private fun grab(retriever: MediaMetadataRetriever, atUs: Long, maxPx: Int): Bitmap? {
    val bitmap = if (Build.VERSION.SDK_INT >= 27) {
      retriever.getScaledFrameAtTime(atUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, maxPx, maxPx)
    } else {
      retriever.getFrameAtTime(atUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
    }
    return bitmap?.let { fit(it, maxPx) }
  }

  /** Mean luma (0–255) over a 16×16 sample grid. */
  private fun brightness(bitmap: Bitmap): Double {
    var sum = 0.0
    val steps = 16
    for (i in 0 until steps) {
      for (j in 0 until steps) {
        val c = bitmap.getPixel(i * (bitmap.width - 1) / (steps - 1), j * (bitmap.height - 1) / (steps - 1))
        sum += 0.299 * ((c shr 16) and 0xFF) + 0.587 * ((c shr 8) and 0xFF) + 0.114 * (c and 0xFF)
      }
    }
    return sum / (steps * steps)
  }

  /** Cover art embedded in an audio file, if any. */
  private fun cover(retriever: MediaMetadataRetriever, maxPx: Int): Bitmap? {
    val bytes = retriever.embeddedPicture ?: return null
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxPx) sample *= 2
    val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
    return decoded?.let { fit(it, maxPx) }
  }

  private fun fit(bitmap: Bitmap, maxPx: Int): Bitmap {
    val longest = maxOf(bitmap.width, bitmap.height)
    if (longest <= maxPx) return bitmap
    val scale = maxPx.toFloat() / longest
    return Bitmap.createScaledBitmap(
      bitmap,
      (bitmap.width * scale).toInt().coerceAtLeast(1),
      (bitmap.height * scale).toInt().coerceAtLeast(1),
      true,
    )
  }

  /** Written next to the target then renamed: never a half-written picture. */
  private fun writeJpeg(bitmap: Bitmap, out: File): Boolean {
    out.parentFile?.mkdirs()
    val staging = File(out.parentFile, out.name + ".part")
    FileOutputStream(staging).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 80, it) }
    return staging.renameTo(out) || run { staging.delete(); false }
  }

  /** Codec names as ffprobe reports them (same UI labels), and the sample rate. */
  private fun codecs(path: String): Triple<String?, String?, Int?> {
    val extractor = MediaExtractor()
    var video: String? = null
    var audio: String? = null
    var rate: Int? = null
    try {
      extractor.setDataSource(path)
      for (i in 0 until extractor.trackCount) {
        val format = extractor.getTrackFormat(i)
        val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
        if (mime.startsWith("video/") && video == null) video = VIDEO_CODECS[mime] ?: mime.removePrefix("video/")
        if (mime.startsWith("audio/") && audio == null) {
          audio = AUDIO_CODECS[mime] ?: mime.removePrefix("audio/")
          if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        }
      }
    } catch (_: Exception) {
      // Codecs are informative only.
    } finally {
      extractor.release()
    }
    return Triple(video, audio, rate)
  }

  private fun container(mime: String?): String? = when (mime) {
    null -> null
    "video/mp4", "audio/mp4" -> "mp4"
    "video/webm", "audio/webm" -> "webm"
    "video/x-matroska" -> "matroska"
    "audio/mpeg" -> "mp3"
    "audio/flac" -> "flac"
    "audio/ogg" -> "ogg"
    else -> mime.substringAfter('/')
  }

  private companion object {
    /** Mean luma below which a frame is treated as black. */
    const val DARK_FRAME = 28.0

    val LOSSLESS = setOf("flac", "alac", "pcm_s16le", "pcm_s24le", "raw")

    val VIDEO_CODECS = mapOf(
      "video/avc" to "h264",
      "video/hevc" to "hevc",
      "video/x-vnd.on2.vp9" to "vp9",
      "video/x-vnd.on2.vp8" to "vp8",
      "video/av01" to "av1",
      "video/mp4v-es" to "mpeg4",
    )
    val AUDIO_CODECS = mapOf(
      "audio/mp4a-latm" to "aac",
      "audio/mpeg" to "mp3",
      "audio/opus" to "opus",
      "audio/vorbis" to "vorbis",
      "audio/flac" to "flac",
      "audio/alac" to "alac",
      "audio/raw" to "raw",
    )
  }
}
