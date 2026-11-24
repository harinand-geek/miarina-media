package org.miarina.media

import android.Manifest
import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
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
import java.io.File
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

  // Supprimer du téléphone: the answer waits for the system confirmation.
  private var pendingDelete: MethodChannel.Result? = null
  private var retryUris: List<Uri> = emptyList()

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
      "delete" -> delete(call.argument<List<String>>("paths") ?: emptyList(), result)
      "share" -> share(call.argument<String>("path"), call.argument<String>("title"), result)
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

  /** The MediaStore item of an absolute path, in its audio or video collection. */
  private fun uriOf(path: String): Uri? {
    val volumes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      MediaStore.getExternalVolumeNames(activity).toList()
    } else {
      listOf("external")
    }
    for (volume in volumes) {
      for (collection in listOf(
        MediaStore.Audio.Media.getContentUri(volume),
        MediaStore.Video.Media.getContentUri(volume),
      )) {
        activity.contentResolver.query(
          collection,
          arrayOf(MediaStore.MediaColumns._ID),
          "${MediaStore.MediaColumns.DATA} = ?",
          arrayOf(path),
          null,
        )?.use { c ->
          if (c.moveToFirst()) return ContentUris.withAppendedId(collection, c.getLong(0))
        }
      }
    }
    return null
  }

  /** Files of the app's own folders, which it may delete without asking. */
  private fun ownFile(path: String): File? {
    val file = File(path).canonicalFile
    val roots = listOfNotNull(activity.filesDir.parentFile, activity.getExternalFilesDir(null)?.parentFile)
    return file.takeIf { f -> roots.any { f.path.startsWith(it.canonicalPath + File.separator) } }
  }

  /**
   * Supprimer du téléphone: MediaStore items go through the system
   * confirmation (Android 11+), the app's own files are deleted directly.
   * Answers "deleted", "canceled" (the user said no) or "failed".
   */
  private fun delete(paths: List<String>, result: MethodChannel.Result) {
    if (pendingDelete != null || paths.isEmpty()) {
      result.success("failed")
      return
    }
    worker.execute {
      val uris = ArrayList<Uri>()
      var ok = true
      for (path in paths) {
        val uri = try { uriOf(path) } catch (e: Exception) { null }
        if (uri != null) {
          uris.add(uri)
        } else {
          val own = ownFile(path)
          ok = ok && own != null && (!own.exists() || own.delete())
        }
      }
      main.post { deleteUris(uris, ok, result) }
    }
  }

  private fun deleteUris(uris: List<Uri>, filesOk: Boolean, result: MethodChannel.Result) {
    if (uris.isEmpty()) {
      result.success(if (filesOk) "deleted" else "failed")
      return
    }
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        val request = MediaStore.createDeleteRequest(activity.contentResolver, uris)
        pendingDelete = result
        retryUris = emptyList()
        activity.startIntentSenderForResult(request.intentSender, DELETE_CODE, null, 0, 0, 0)
        return
      }
      for (uri in uris) activity.contentResolver.delete(uri, null, null)
      result.success(if (filesOk) "deleted" else "failed")
    } catch (e: Exception) {
      if (Build.VERSION.SDK_INT == Build.VERSION_CODES.Q && e is RecoverableSecurityException) {
        // Android 10: one confirmation, then the deletes again.
        pendingDelete = result
        retryUris = uris
        try {
          activity.startIntentSenderForResult(
            e.userAction.actionIntent.intentSender, DELETE_CODE, null, 0, 0, 0,
          )
          return
        } catch (_: Exception) {
          pendingDelete = null
        }
      }
      result.success("failed")
    }
  }

  /** Called by MainActivity with the system confirmation's answer. */
  fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
    if (requestCode != DELETE_CODE) return false
    val result = pendingDelete ?: return true
    pendingDelete = null
    if (resultCode != Activity.RESULT_OK) {
      result.success("canceled")
      return true
    }
    val again = retryUris
    retryUris = emptyList()
    if (again.isEmpty()) {
      result.success("deleted")
    } else {
      try {
        for (uri in again) activity.contentResolver.delete(uri, null, null)
        result.success("deleted")
      } catch (e: Exception) {
        result.success("failed")
      }
    }
    return true
  }

  /** Partager: the system share sheet with the file's MediaStore item. */
  private fun share(path: String?, title: String?, result: MethodChannel.Result) {
    if (path == null) {
      result.success(false)
      return
    }
    worker.execute {
      val uri = try { uriOf(path) } catch (e: Exception) { null }
      main.post {
        if (uri == null) {
          result.success(false)
          return@post
        }
        val send = Intent(Intent.ACTION_SEND)
          .setType(activity.contentResolver.getType(uri) ?: "*/*")
          .putExtra(Intent.EXTRA_STREAM, uri)
          .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
          activity.startActivity(Intent.createChooser(send, title))
          result.success(true)
        } catch (e: Exception) {
          result.success(false)
        }
      }
    }
  }

  companion object {
    private const val DELETE_CODE = 4108
    private const val REQUEST_CODE = 4107
    private const val MAX_ITEMS = 20_000
    private const val MIN_AUDIO_MS = 30_000L
  }
}
