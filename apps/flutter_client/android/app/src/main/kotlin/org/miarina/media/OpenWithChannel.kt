package org.miarina.media

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * "Open with Miarina Media" (owner's request, as other media players): a
 * music or video file handed over by another app (file manager, download
 * list, attachment) through ACTION_VIEW. Dart asks for the file the app was
 * started with ("initial"); a file handed over while it runs arrives as
 * "open". Read only: the file is played, never copied or modified.
 */
class OpenWithChannel(
  private val activity: Activity,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
  private val channel = MethodChannel(messenger, "org.miarina.media/open_with")
  private var initial: Map<String, Any?>? = null

  init {
    channel.setMethodCallHandler(this)
    initial = describe(activity.intent)
  }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      // Given once: a later rebuild of the UI does not replay it.
      "initial" -> {
        result.success(initial)
        initial = null
      }
      else -> result.notImplemented()
    }
  }

  /** A file handed over while the app runs (singleTop activity). */
  fun onNewIntent(intent: Intent) {
    describe(intent)?.let { channel.invokeMethod("open", it) }
  }

  /**
   * `uri` to play, a display `name`, the `mime` type, and `path` when the
   * file is in the phone's media index (so the library entry is found).
   */
  private fun describe(intent: Intent?): Map<String, Any?>? {
    // "Download complete · tap to play" (DownloadNotificationsChannel).
    intent?.getStringExtra(DownloadNotificationsChannel.EXTRA_PLAY_TASK)?.let {
      intent.removeExtra(DownloadNotificationsChannel.EXTRA_PLAY_TASK)
      return mapOf("task" to it.take(64))
    }
    // A link shared from another app ("Share to Miarina Media"): its first
    // web address, checked again by the core before anything is fetched.
    if (intent?.action == Intent.ACTION_SEND) {
      // Untrusted text from another app: bounded here, parsed and checked
      // again by the core.
      val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.take(MAX_SHARED_CHARS) ?: return null
      val link = WEB_LINK.find(text)?.value ?: return null
      return mapOf("link" to link)
    }
    if (intent?.action != Intent.ACTION_VIEW) return null
    val uri = intent.data ?: return null
    if (uri.scheme != "content" && uri.scheme != "file") return null
    val mime = intent.type ?: activity.contentResolver.getType(uri)
    return mapOf(
      "uri" to uri.toString(),
      "name" to displayName(uri),
      "mime" to mime,
      "path" to filePath(uri),
    )
  }

  private fun displayName(uri: Uri): String? {
    if (uri.scheme == "file") return uri.lastPathSegment
    return try {
      activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (e: Exception) {
      null
    }
  }

  private companion object {
    val WEB_LINK = Regex("""https?://\S+""")
    const val MAX_SHARED_CHARS = 4096
  }

  /** The file's path for a MediaStore entry or a file:// URI, else null. */
  private fun filePath(uri: Uri): String? {
    if (uri.scheme == "file") return uri.path
    if (uri.authority != MediaStore.AUTHORITY) return null
    return try {
      activity.contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)
        ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        ?.takeIf { it.startsWith("/") }
    } catch (e: Exception) {
      null
    }
  }
}
