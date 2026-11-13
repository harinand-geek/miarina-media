package org.miarina.media

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import app.tauri.annotation.Command
import app.tauri.annotation.Permission
import app.tauri.annotation.PermissionCallback
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.Invoke
import app.tauri.plugin.JSArray
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import java.util.concurrent.Executors

/**
 * Media already on the phone (AND-06): read access to music and videos,
 * then their paths from the system media index (internal storage and SD
 * card). Read only: nothing is copied, moved or deleted here. Android 13+
 * asks for "Music and audio" and "Videos" separately; older versions use
 * the storage read permission.
 */
@TauriPlugin(
  permissions = [
    Permission(strings = [Manifest.permission.READ_MEDIA_AUDIO], alias = "audio"),
    Permission(strings = [Manifest.permission.READ_MEDIA_VIDEO], alias = "video"),
    Permission(strings = [Manifest.permission.READ_EXTERNAL_STORAGE], alias = "storage"),
  ]
)
class DeviceMediaPlugin(private val activity: Activity) : Plugin(activity) {
  private val worker = Executors.newSingleThreadExecutor()

  private val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU

  private fun state(alias: String): String =
    getPermissionState(if (modern) alias else "storage")?.toString() ?: "prompt"

  private fun states(): JSObject {
    val out = JSObject()
    out.put("audio", state("audio"))
    out.put("video", state("video"))
    return out
  }

  @Command
  fun access(invoke: Invoke) {
    invoke.resolve(states())
  }

  /** Shows the system permission dialogs, then answers the new state. */
  @Command
  fun request(invoke: Invoke) {
    val aliases = if (modern) arrayOf("audio", "video") else arrayOf("storage")
    if (aliases.all { getPermissionState(it).toString() == "granted" }) {
      invoke.resolve(states())
      return
    }
    requestPermissionForAliases(aliases, invoke, "requested")
  }

  @PermissionCallback
  private fun requested(invoke: Invoke) {
    invoke.resolve(states())
  }

  /** App details in the system settings, where a refusal is undone. */
  @Command
  fun openSettings(invoke: Invoke) {
    val intent = Intent(
      Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
      Uri.fromParts("package", activity.packageName, null),
    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    try {
      activity.startActivity(intent)
      invoke.resolve()
    } catch (e: Exception) {
      invoke.reject("settings unavailable")
    }
  }

  /**
   * Paths of the music (not ringtones, alarms or notification sounds, nor
   * clips shorter than 30 s) and videos the granted permissions allow.
   */
  @Command
  fun list(invoke: Invoke) {
    worker.execute {
      try {
        val paths = JSArray()
        var count = 0
        val volumes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
          MediaStore.getExternalVolumeNames(activity).toList()
        } else {
          listOf("external")
        }
        val add = { path: String ->
          if (count < MAX_ITEMS && path.startsWith("/")) {
            paths.put(path)
            count++
          }
        }
        for (volume in volumes) {
          if (state("audio") == "granted") {
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
          if (state("video") == "granted") {
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
        out.put("paths", paths)
        invoke.resolve(out)
      } catch (e: Exception) {
        invoke.reject("media index unavailable")
      }
    }
  }

  companion object {
    private const val MAX_ITEMS = 20_000
    private const val MIN_AUDIO_MS = 30_000L
  }
}
