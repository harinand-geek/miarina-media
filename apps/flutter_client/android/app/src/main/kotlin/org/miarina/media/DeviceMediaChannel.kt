package org.miarina.media

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * The phone's music and videos (A-06, A-07), ported from DeviceMediaPlugin of
 * the Tauri app: read access only, through MediaStore, after the user's
 * consent. Android 13+ asks READ_MEDIA_AUDIO and READ_MEDIA_VIDEO (plus
 * POST_NOTIFICATIONS for the lock-screen controls); older versions ask
 * READ_EXTERNAL_STORAGE. Nothing leaves the device.
 */
class DeviceMediaChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
  private val channel = MethodChannel(messenger, "org.miarina.media/device_media")
  private val worker = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())
  private var pending: MethodChannel.Result? = null

  private val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU

  init {
    channel.setMethodCallHandler(this)
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
    worker.shutdown()
  }

  private fun granted(permission: String): Boolean =
    ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED

  private fun audioGranted(): Boolean =
    granted(if (modern) Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE)

  private fun videoGranted(): Boolean =
    granted(if (modern) Manifest.permission.READ_MEDIA_VIDEO else Manifest.permission.READ_EXTERNAL_STORAGE)

  private fun states(): MutableMap<String, Any> = mutableMapOf(
    "audio" to if (audioGranted()) "granted" else "prompt",
    "video" to if (videoGranted()) "granted" else "prompt",
  )

  override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "access" -> result.success(states())
      "request" -> request(result)
      "openSettings" -> openSettings(result)
      "list" -> list(result)
      else -> result.notImplemented()
    }
  }

  /** Shows the system permission dialogs, then answers the new state. */
  private fun request(result: MethodChannel.Result) {
    val wanted = if (modern) {
      arrayOf(
        Manifest.permission.READ_MEDIA_AUDIO,
        Manifest.permission.READ_MEDIA_VIDEO,
        Manifest.permission.POST_NOTIFICATIONS,
      )
    } else {
      arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }
    val missing = wanted.filterNot(::granted)
    if (missing.isEmpty() || pending != null) {
      result.success(states())
      return
    }
    pending = result
    ActivityCompat.requestPermissions(activity, missing.toTypedArray(), REQUEST_CODE)
  }

  /** Called by MainActivity with the system dialog's answer. */
  fun onPermissionsResult(requestCode: Int): Boolean {
    if (requestCode != REQUEST_CODE) return false
    pending?.success(states())
    pending = null
    return true
  }

  /** App details in the system settings, where a refusal is undone. */
  private fun openSettings(result: MethodChannel.Result) {
    val intent = Intent(
      Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
      Uri.fromParts("package", activity.packageName, null),
    )
    try {
      activity.startActivity(intent)
      result.success(null)
    } catch (e: Exception) {
      result.error("settings", "settings unavailable", null)
    }
  }

  /**
   * Paths of the music (not ringtones, alarms or notification sounds, nor
   * clips shorter than 30 s) and videos the granted permissions allow.
   */
  private fun list(result: MethodChannel.Result) {
    worker.execute {
      try {
        val paths = ArrayList<String>()
        val volumes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
          MediaStore.getExternalVolumeNames(activity).toList()
        } else {
          listOf("external")
        }
        val add = { path: String ->
          if (paths.size < MAX_ITEMS && path.startsWith("/")) paths.add(path)
        }
        for (volume in volumes) {
          if (audioGranted()) {
            activity.contentResolver.query(
              MediaStore.Audio.Media.getContentUri(volume),
              arrayOf(MediaStore.MediaColumns.DATA, MediaStore.Audio.Media.DURATION),
              "${MediaStore.Audio.Media.IS_MUSIC} != 0",
              null,
              null,
            )?.use { c ->
              val data = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
              val duration = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
              while (c.moveToNext()) {
                val ms = if (c.isNull(duration)) 0L else c.getLong(duration)
                if (ms in 1 until MIN_AUDIO_MS) continue
                c.getString(data)?.let(add)
              }
            }
          }
          if (videoGranted()) {
            activity.contentResolver.query(
              MediaStore.Video.Media.getContentUri(volume),
              arrayOf(MediaStore.MediaColumns.DATA),
              null,
              null,
              null,
            )?.use { c ->
              val data = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
              while (c.moveToNext()) c.getString(data)?.let(add)
            }
          }
        }
        val out = states()
        out["paths"] = paths
        main.post { result.success(out) }
      } catch (e: Exception) {
        main.post { result.error("list", "media index unavailable", null) }
      }
    }
  }

  companion object {
    private const val REQUEST_CODE = 4107
    private const val MAX_ITEMS = 20_000
    private const val MIN_AUDIO_MS = 30_000L
  }
}
