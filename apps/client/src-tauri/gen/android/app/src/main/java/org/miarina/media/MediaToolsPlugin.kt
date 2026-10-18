package org.miarina.media

import android.app.Activity
import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.os.Build
import android.provider.MediaStore
import app.tauri.annotation.Command
import app.tauri.annotation.InvokeArg
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

@InvokeArg
class PublishArgs {
  lateinit var path: String
}

@InvokeArg
class ProbeArgs {
  lateinit var path: String
  /** Where to write a JPEG, or null when the entry already has a picture. */
  var thumbnail: String? = null
  var maxPx: Int = 360
}

/**
 * Library metadata on Android, where ffprobe/FFmpeg do not run: duration,
 * size and codecs (MediaMetadataRetriever + MediaExtractor) and a JPEG
 * thumbnail (a frame 10 % in, or the embedded cover of an audio file).
 * Paths come from Rust (library entries, thumbnail folder), never from the
 * page. Work runs on one background thread: the Rust worker already bounds
 * how many files are read at once.
 */
@TauriPlugin
class MediaToolsPlugin(private val activity: Activity) : Plugin(activity) {
  private val worker = Executors.newSingleThreadExecutor()

  /**
   * Makes a finished download in shared storage (Movies/, Music/) visible to
   * the gallery and music apps: indexes it, then clears the "pending" flag
   * the system can leave on a file moved in from the app's own folder.
   */
  @Command
  fun publish(invoke: Invoke) {
    val args = invoke.parseArgs(PublishArgs::class.java)
    MediaScannerConnection.scanFile(activity, arrayOf(args.path), null) { _, uri ->
      var visible = uri != null
      if (uri != null && Build.VERSION.SDK_INT >= 29) {
        try {
          val values = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
          activity.contentResolver.update(uri, values, null, null)
        } catch (e: Exception) {
          visible = false
        }
      }
      val result = JSObject()
      result.put("indexed", visible)
      invoke.resolve(result)
    }
  }

  @Command
  fun probe(invoke: Invoke) {
    val args = invoke.parseArgs(ProbeArgs::class.java)
    worker.execute {
      try {
        invoke.resolve(read(args))
      } catch (e: Exception) {
        invoke.reject(e.message ?: "The file could not be read")
      }
    }
  }

  override fun onDestroy() {
    worker.shutdownNow()
  }

  private fun read(args: ProbeArgs): JSObject {
    val retriever = MediaMetadataRetriever()
    try {
      retriever.setDataSource(args.path)
      val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
      val hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes"
      var width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
      var height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
      val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
      if (rotation == 90 || rotation == 270) {
        width = height.also { height = width }
      }
      val (videoCodec, audioCodec) = codecs(args.path)

      val probe = JSObject()
      durationMs?.let { probe.put("durationSecs", it / 1000.0) }
      if (hasVideo) {
        width?.let { probe.put("width", it) }
        height?.let { probe.put("height", it) }
      }
      videoCodec?.let { probe.put("videoCodec", it) }
      audioCodec?.let { probe.put("audioCodec", it) }
      container(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE))?.let {
        probe.put("container", it)
      }
      probe.put("hasVideo", hasVideo)

      var written = false
      args.thumbnail?.let { out ->
        val picture = if (hasVideo) frame(retriever, durationMs, args.maxPx) else cover(retriever, args.maxPx)
        if (picture != null) written = writeJpeg(picture, File(out))
      }

      val result = JSObject()
      result.put("probe", probe)
      result.put("thumbnailWritten", written)
      return result
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
    return Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt().coerceAtLeast(1), (bitmap.height * scale).toInt().coerceAtLeast(1), true)
  }

  /** Written next to the target then renamed: never a half-written picture. */
  private fun writeJpeg(bitmap: Bitmap, out: File): Boolean {
    val staging = File(out.parentFile, out.name + ".part")
    FileOutputStream(staging).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 80, it) }
    return staging.renameTo(out) || run { staging.delete(); false }
  }

  /** Codec names as ffprobe reports them, so the UI labels stay the same. */
  private fun codecs(path: String): Pair<String?, String?> {
    val extractor = MediaExtractor()
    var video: String? = null
    var audio: String? = null
    try {
      extractor.setDataSource(path)
      for (i in 0 until extractor.trackCount) {
        val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
        if (mime.startsWith("video/") && video == null) video = VIDEO_CODECS[mime] ?: mime.removePrefix("video/")
        if (mime.startsWith("audio/") && audio == null) audio = AUDIO_CODECS[mime] ?: mime.removePrefix("audio/")
      }
    } catch (_: Exception) {
      // Codecs are informative only.
    } finally {
      extractor.release()
    }
    return video to audio
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
    )
  }
}
