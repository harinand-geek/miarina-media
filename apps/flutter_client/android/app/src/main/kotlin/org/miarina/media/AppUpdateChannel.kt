package org.miarina.media

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * In-app updates on Android (Réglages › Mises à jour): the core has
 * downloaded the APK named by the signed manifest and checked its size and
 * SHA-256 just before; this hands it to the system installer, which asks
 * the user. Only files in the app's own cache/updates folder are served
 * (res/xml/update_paths.xml). Channel org.miarina.media/app_update.
 */
class AppUpdateChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

  private val channel = MethodChannel(messenger, "org.miarina.media/app_update")

  init {
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "installApk" -> {
        val path = call.argument<String>("path")
        val dir = File(activity.cacheDir, "updates").canonicalFile
        val file = path?.let { File(it).canonicalFile }
        if (file == null || file.parentFile != dir || !file.isFile || !file.name.endsWith(".apk")) {
          result.error("update", "Update file not found", null)
          return
        }
        // Android 8+: the user allows Miarina Media to install apps once.
        if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
          activity.startActivity(
            Intent(
              Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
              Uri.parse("package:${activity.packageName}"),
            ),
          )
          result.success("permission")
          return
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
        val intent = Intent(Intent.ACTION_VIEW)
          .setDataAndType(uri, "application/vnd.android.package-archive")
          .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
          activity.startActivity(intent)
          result.success("started")
        } catch (e: Exception) {
          result.error("update", e.message ?: "No installer", null)
        }
      }
      else -> result.notImplemented()
    }
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }
}
