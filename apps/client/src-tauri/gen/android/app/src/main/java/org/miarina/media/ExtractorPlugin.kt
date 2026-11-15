package org.miarina.media

import android.app.Activity
import app.tauri.annotation.Command
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.ffmpeg.FFmpeg
import java.io.File
import java.util.concurrent.Executors

/** Extract packaged tools off the UI thread. No executable paths come from JS.
 * Layout is pinned to youtubedl-android 0.18.1; Rust runs the process so output
 * stays bounded and the persistent download manager remains the sole owner.
 */
@TauriPlugin
class ExtractorPlugin(private val activity: Activity) : Plugin(activity) {
  @Command
  fun prepare(invoke: Invoke) {
    worker.execute {
      try {
        val context = activity.applicationContext
        YoutubeDL.init(context)
        FFmpeg.init(context)
        val base = File(context.noBackupFilesDir, YoutubeDL.baseName)
        // Upstream only copies yt-dlp when absent. Always restore the APK's
        // version atomically so installing a newer APK actually updates it.
        // Our pinned yt-dlp is `res/raw/ytdlp`: same name as the library's,
        // so it replaces that copy in the APK (one 3 MB script, not two).
        val script = File(File(base, YoutubeDL.ytdlpDirName), YoutubeDL.ytdlpBin)
        val staged = File(script.parentFile, "packaged.tmp")
        context.resources.openRawResource(R.raw.ytdlp).use { input ->
          staged.outputStream().use { output -> input.copyTo(output) }
        }
        android.system.Os.rename(staged.absolutePath, script.absolutePath)
        val packages = File(base, "packages")
        val python = File(packages, "python/usr")
        val bin = File(context.applicationInfo.nativeLibraryDir)
        val result = JSObject()
        result.put("python", File(bin, "libpython.so").absolutePath)
        result.put("script", script.absolutePath)
        result.put("ffmpeg", File(bin, "libffmpeg.so").absolutePath)
        result.put("quickjs", File(bin, "libqjs.so").absolutePath)
        result.put("pythonHome", python.absolutePath)
        result.put("libraryPath", listOf(File(python, "lib"), File(packages, "ffmpeg/usr/lib")).joinToString(":") { it.absolutePath })
        result.put("certificates", File(python, "etc/tls/cert.pem").absolutePath)
        result.put("temp", context.cacheDir.absolutePath)
        result.put("bin", bin.absolutePath)
        invoke.resolve(result)
      } catch (_: Exception) {
        invoke.reject("Unable to prepare packaged media tools")
      } catch (_: LinkageError) {
        invoke.reject("Packaged media tools could not be loaded")
      }
    }
  }

  companion object {
    private val worker = Executors.newSingleThreadExecutor()
  }
}
