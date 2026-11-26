package org.miarina.media

import android.app.Activity
import android.content.ContentValues
import android.media.MediaScannerConnection
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Obtenir on Android, ported from ExtractorPlugin and MediaToolsPlugin of the
 * Tauri app:
 * - "prepare": unpacks the APK's Python, FFmpeg and QuickJS
 *   (youtubedl-android 0.18.1) and the pinned yt-dlp (res/raw/ytdlp), then
 *   answers their paths. The Rust core runs the processes, so output stays
 *   bounded and the download manager owns them; no path comes from Dart.
 * - "publish": a finished download in Music/ or Movies/ joins the phone's
 *   media index (gallery, other players).
 */
class MediaToolsChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
  private val channel = MethodChannel(messenger, "org.miarina.media/media_tools")
  private val worker = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())

  init {
    channel.setMethodCallHandler(this)
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    worker.shutdown()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "prepare" -> worker.execute {
        val reply = try {
          prepare()
        } catch (e: Exception) {
          null
        } catch (e: LinkageError) {
          null
        }
        main.post {
          if (reply == null) {
            result.error("prepare", "Unable to prepare packaged media tools", null)
          } else {
            result.success(reply)
          }
        }
      }
      "publish" -> publish(call.argument<String>("path"), result)
      // Online listening: automatic obtaining may wait for Wi-Fi.
      "onWifi" -> result.success(onWifi())
      "saveToDownloads" -> saveToDownloads(call.argument<String>("path"), call.argument<String>("name"), result)
      else -> result.notImplemented()
    }
  }

  private fun prepare(): Map<String, String?> {
    val context = activity.applicationContext
    YoutubeDL.init(context)
    FFmpeg.init(context)
    val base = File(context.noBackupFilesDir, YoutubeDL.baseName)
    // Upstream only copies yt-dlp when absent. Always restore the APK's
    // version atomically so installing a newer APK actually updates it.
    // Our pinned yt-dlp is `res/raw/ytdlp`: same name as the library's, so
    // it replaces that copy in the APK (one 3 MB script, not two).
    val script = File(File(base, YoutubeDL.ytdlpDirName), YoutubeDL.ytdlpBin)
    val staged = File(script.parentFile, "packaged.tmp")
    context.resources.openRawResource(R.raw.ytdlp).use { input ->
      staged.outputStream().use { output -> input.copyTo(output) }
    }
    android.system.Os.rename(staged.absolutePath, script.absolutePath)
    val packages = File(base, "packages")
    val python = File(packages, "python/usr")
    val bin = File(context.applicationInfo.nativeLibraryDir)
    // Download folders, as in the Tauri app (shared_storage.rs): from
    // Android 11 an app writes Movies/Miarina and Music/Miarina without any
    // permission and the files stay after uninstall; before, they stay in
    // the app's own folder. Temporary files: the app's folder on the same
    // storage, since the shared folders only accept media files.
    val own = context.getExternalFilesDir(null) ?: context.filesDir
    val root = own.absolutePath.substringBefore("/Android/data/", "")
    val shared = Build.VERSION.SDK_INT >= 30 && root.isNotEmpty()
    val videoDir = if (shared) File(root, "Movies/Miarina") else File(own, "Movies/Miarina")
    val audioDir = if (shared) File(root, "Music/Miarina") else null
    return mapOf(
      "videoDir" to videoDir.absolutePath,
      "audioDir" to audioDir?.absolutePath,
      "stagingDir" to File(own, "partial").absolutePath,
      "python" to File(bin, "libpython.so").absolutePath,
      "script" to script.absolutePath,
      "ffmpeg" to File(bin, "libffmpeg.so").absolutePath,
      "quickjs" to File(bin, "libqjs.so").absolutePath,
      "pythonHome" to python.absolutePath,
      "libraryPath" to listOf(File(python, "lib"), File(packages, "ffmpeg/usr/lib"))
        .joinToString(":") { it.absolutePath },
      "certificates" to File(python, "etc/tls/cert.pem").absolutePath,
      "temp" to context.cacheDir.absolutePath,
      "bin" to bin.absolutePath,
    )
  }

  /**
   * A file the app made (an exported playlist) copied into
   * Download/Miarina through MediaStore: no permission from Android 10.
   * Returns the place shown to the user, or null.
   */
  private fun saveToDownloads(path: String?, name: String?, result: MethodChannel.Result) {
    if (path == null || name == null || !File(path).isFile || Build.VERSION.SDK_INT < 29) {
      result.success(null)
      return
    }
    worker.execute {
      val shown = try {
        val values = ContentValues().apply {
          put(MediaStore.MediaColumns.DISPLAY_NAME, name)
          put(MediaStore.MediaColumns.MIME_TYPE, "audio/x-mpegurl")
          put(MediaStore.MediaColumns.RELATIVE_PATH, "Download/Miarina")
          put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = activity.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
          ?: throw IllegalStateException("no entry")
        resolver.openOutputStream(uri)?.use { out -> File(path).inputStream().use { it.copyTo(out) } }
        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        // The name MediaStore kept (it adds " (1)" when taken).
        resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use { c ->
          if (c.moveToFirst()) "Download/Miarina/" + c.getString(0) else "Download/Miarina/$name"
        } ?: "Download/Miarina/$name"
      } catch (e: Exception) {
        null
      }
      main.post { result.success(shown) }
    }
  }

  private fun publish(path: String?, result: MethodChannel.Result) {
    if (path == null || !File(path).isFile) {
      result.success(false)
      return
    }
    MediaScannerConnection.scanFile(activity, arrayOf(path), null) { _, uri ->
      var visible = uri != null
      if (uri != null && Build.VERSION.SDK_INT >= 29) {
        try {
          val values = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
          activity.contentResolver.update(uri, values, null, null)
        } catch (e: Exception) {
          visible = false
        }
      }
      main.post { result.success(visible) }
    }
  }

  /** The active network is Wi-Fi or Ethernet (not mobile data). */
  private fun onWifi(): Boolean {
    val cm = activity.getSystemService(ConnectivityManager::class.java) ?: return false
    val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
    return caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
      caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
  }
}
